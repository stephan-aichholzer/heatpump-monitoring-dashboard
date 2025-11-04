# Heat Pump Monitoring Dashboard - Architecture

## Overview

Comprehensive heating system monitoring platform with integrated energy metering, heat pump monitoring, and temperature sensing. Runs on Raspberry Pi (or any Docker host) using containerized services with Prometheus and Grafana.

**Version: v2.2** - Power spike filtering • Monotonic counters • Heat pump integration • Automated backup

## System Purpose

Evolved from simple energy meter reader into a **complete heating system monitoring platform**:

1. **Energy metering** - Modbus power/energy monitoring (WAGO default, adaptable to any meter)
2. **Heat pump monitoring** - Real-time status via [lg-r290-control](https://github.com/stephan-aichholzer/lg-r290-control)
3. **Temperature sensing** - Multi-zone climate via [shelly-blu-ht](https://github.com/stephan-aichholzer/shelly-blu-ht)
4. **Unified analytics** - Cross-system correlation and insights

**Modular design** - Use standalone or fully integrated

## Integrated System Components

### 1. Energy Metering (this project)
- 3-phase power and energy monitoring
- Grid quality metrics (frequency, power factor)
- Centralized Prometheus + Grafana
- **Default**: WAGO (adaptable to Shelly Pro 3EM, any Modbus meter)

### 2. [LG R290 Heat Pump Control](https://github.com/stephan-aichholzer/lg-r290-control) *(optional)*
- Real-time heat pump status (flow/return temps, compressor state)
- Operating mode monitoring (Auto/Manual heating)
- Network: `heatpump_dashboard_default`

### 3. [Shelly BLU Temperature & Thermostat](https://github.com/stephan-aichholzer/shelly-blu-ht) *(optional)*
- Temperature/humidity from Shelly BLU H&T sensors
- Thermostat control state and target temperatures
- Network: `shelly_bt_temp_default`

## Physical Architecture

### Complete Heating Ecosystem

```
┌────────────────────────────────────────────────────────────┐
│                  Complete Heating System                   │
└────────────────────────────────────────────────────────────┘

┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│ Shelly BLU   │         │  LG R290     │         │ Energy Meter │
│ Sensors      │         │  Heat Pump   │         │ (Modbus)     │
│ (Bluetooth)  │         │  (Modbus)    │         │              │
└──────┬───────┘         └──────┬───────┘         └──────┬───────┘
       │                        │                        │
       │ BT                     │ RS485                  │ RS485/TCP
       ▼                        ▼                        ▼
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│ Shelly Pro 2 │         │  Waveshare   │         │  Modbus      │
│ (Gateway)    │         │  RS485-ETH   │         │  Gateway     │
└──────┬───────┘         └──────┬───────┘         └──────┬───────┘
       │                        │                        │
       │ Ethernet               │ Ethernet               │ Ethernet
       └────────────────────────┼────────────────────────┘
                                │
                                ▼
         ┌──────────────────────────────────────────────┐
         │         Raspberry Pi Host System             │
         │                                              │
         │  ┌────────────────────────────────────────┐ │
         │  │  Docker Containers                     │ │
         │  │  ┌──────────────────────────────────┐ │ │
         │  │  │  modbus_exporter:9100            │ │ │
         │  │  │  prometheus:9090                 │ │ │
         │  │  │  grafana:3000                    │ │ │
         │  │  └──────────────────────────────────┘ │ │
         │  └────────────────────────────────────────┘ │
         │                                              │
         │  External Integrations (Docker networks):   │
         │  • iot-api:8000 (shelly_bt_temp_default)   │
         │  • lg_r290_service:8000 (default network)   │
         └──────────────────────────────────────────────┘
```

### Individual System: Energy Meter

```
Energy Meter → Modbus → Gateway → TCP/IP → Raspberry Pi → Exporter → Prometheus → Grafana
(3-phase)      RS485/   (if RS485)  (LAN)    (Docker)    (:9100)    (:9090)     (:3000)
               TCP
```

## Software Architecture

### Docker Stack

```
┌─────────────────────────────────────────────────────────┐
│  Docker Compose (heatpump_dashboard)                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌───────────────┐  ┌───────────────┐  ┌────────────┐ │
│  │ Modbus        │  │ Prometheus    │  │ Grafana    │ │
│  │ Exporter      │─►│ Time Series   │─►│ Dashboard  │ │
│  │ :9100         │  │ :9090         │  │ :3000      │ │
│  └───────────────┘  └───────────────┘  └────────────┘ │
│                                                         │
│  Persistent Volumes:                                    │
│  • prometheus_data/ (1yr retention)                     │
│  • grafana_data/ (dashboards, config)                   │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

```
┌──────────────────────────────────────────────────────┐
│                Data Collection (30s interval)        │
├──────────────────────────────────────────────────────┤
│                                                      │
│  Energy Meter → modbus_exporter:9100 ───────┐      │
│  Temp Sensors → iot-api:8000/metrics ────────┼────► │
│  Heat Pump → lg_r290_service:8000/metrics ───┘      │
│                                                      │
└───────────────────────┬──────────────────────────────┘
                        │
                        ▼
         ┌──────────────────────────────┐
         │  prometheus:9090             │
         │  • Scrapes all targets       │
         │  • 1-year retention          │
         │  • PromQL queries            │
         └──────────────┬───────────────┘
                        │
                        ▼
         ┌──────────────────────────────┐
         │  grafana:3000                │
         │  • Unified dashboard         │
         │  • Cross-system analytics    │
         └──────────────────────────────┘
```

## Component Details

### 1. Modbus Exporter (`exporter/exporter.py`)

**Purpose**: Polls energy meter via Modbus and exposes Prometheus metrics

**Features**:
- Asynchronous Modbus TCP client (Python 3.12)
- 30-second polling interval
- Power spike filtering (v2.2) - Eliminates bus interference
- Monotonic energy counters (v2.2) - Prevents resets
- Auto-reconnect on connection loss

**Monitored Registers** (WAGO default - adapt for your meter):

| Metric | Register | Description | Type |
|--------|----------|-------------|------|
| Total Power | 0x5012 | Combined 3-phase power | Float32 |
| L1/L2/L3 Power | 0x5014/16/18 | Per-phase power | Float32 |
| Frequency | 0x5008 | Grid frequency | Float32 |
| Power Factor | 0x502A | Power factor (Cos φ) | Float32 |
| Total Energy | 0x6000 | Cumulative energy | Float32 |
| L1/L2/L3 Energy | 0x6006/08/0A | Per-phase cumulative | Float32 |

**Prometheus Metrics**:
- `wago_power_total_kw`, `wago_power_L1/L2/L3_kw`
- `wago_energy_total_kwh`, `wago_energy_L1/L2/L3_kwh`
- `wago_frequency_hz`, `wago_power_factor`

**Configuration** (`exporter/exporter.py` lines 45-47):
```python
MODBUS_IP = "192.168.2.10"    # Gateway/meter IP
MODBUS_PORT = 8899            # Gateway/meter port
SLAVE_ID = 2                  # Modbus slave ID
```

### 2. Prometheus

**Purpose**: Time-series database for metrics storage

**Configuration**:
- Scrape interval: 30 seconds
- Retention: 1 year (`--storage.tsdb.retention.time=1y`)
- Data path: `prometheus_data/` volume

**Scrape Targets**:
1. **Energy Meter** - `modbus_exporter:9100`
2. **Temperature Sensors** - `iot-api:8000/metrics` (via [shelly-blu-ht](https://github.com/stephan-aichholzer/shelly-blu-ht))
3. **Heat Pump** - `lg_r290_service:8000/metrics` (via [lg-r290-control](https://github.com/stephan-aichholzer/lg-r290-control))

### 3. Grafana

**Purpose**: Visualization dashboard

**Configuration**:
- Web interface: `:3000` (admin/admin default)
- Data source: `http://prometheus:9090`
- Dashboard: `dashboards/heat_pump_dashboard.json`
- Storage: `grafana_data/` volume

**Features**:
- Unified heating system view
- Color-coded alerts (0-1-2kW thresholds)
- Cross-system analytics
- EU electrical colors (L1=Brown, L2=Black, L3=Grey)

## Network Configuration

### External Access
- **Grafana**: `http://<host>:3000`
- **Prometheus**: `http://<host>:9090`
- **Metrics Endpoint**: `http://<host>:9100/metrics`

### Docker Networks

```
┌────────────────────────────────────────────────────┐
│  Docker Networks                                   │
├────────────────────────────────────────────────────┤
│                                                    │
│  heatpump_dashboard_default (internal)             │
│  • modbus_exporter                                 │
│  • prometheus                                      │
│  • grafana                                         │
│  • lg_r290_service (from external project)         │
│                                                    │
│  shelly_bt_temp_default (external)                 │
│  • iot-api (from external project)                 │
│  • prometheus (bridges to this network)            │
│  • grafana (bridges to this network)               │
└────────────────────────────────────────────────────┘
```

**Configuration** (`docker-compose.yml`):
```yaml
networks:
  default:
    name: heatpump_dashboard_default
  shelly_bt_temp_default:
    external: true  # Created by shelly-blu-ht project
```

## Complete Metrics Reference

### Energy Metering Metrics
*Source: Modbus energy meter*

| Metric Name | Description | Unit |
|-------------|-------------|------|
| `wago_power_total_kw` | Total active power | kW |
| `wago_power_L1/L2/L3_kw` | Per-phase active power | kW |
| `wago_energy_total_kwh` | Total cumulative energy | kWh |
| `wago_energy_L1/L2/L3_kwh` | Per-phase cumulative | kWh |
| `wago_frequency_hz` | Grid frequency | Hz |
| `wago_power_factor` | Power factor (Cos φ) | ratio |

### Heat Pump Metrics
*Source: [lg-r290-control](https://github.com/stephan-aichholzer/lg-r290-control)*

| Metric Name | Description | Unit |
|-------------|-------------|------|
| `heatpump_flow_temperature_celsius` | Flow temperature | °C |
| `heatpump_return_temperature_celsius` | Return temperature | °C |
| `heatpump_outdoor_temperature_celsius` | Outdoor air temp | °C |
| `heatpump_target_temperature_celsius` | Target setpoint | °C |
| `heatpump_power_state` | Power state (0=OFF, 1=ON) | boolean |
| `heatpump_compressor_running` | Compressor state | boolean |
| `heatpump_water_pump_running` | Water pump state | boolean |
| `heatpump_operating_mode` | Mode (0=Standby, 1=Cooling, 2=Heating, 3=Auto) | enum |
| `heatpump_temperature_delta_celsius` | Flow - return delta | °C |

### Temperature Sensor Metrics
*Source: [shelly-blu-ht](https://github.com/stephan-aichholzer/shelly-blu-ht)*

| Metric Name | Description | Unit |
|-------------|-------------|------|
| `sensor_temperature_celsius` | Temperature reading | °C |
| `sensor_humidity_percent` | Humidity reading | % |
| `sensor_battery_percent` | Battery level | % |
| `sensor_last_seen_timestamp` | Last update time | unix timestamp |
| `thermostat_switch_state` | Thermostat state (0=OFF, 1=ON) | boolean |
| `thermostat_target_temperature_celsius` | Target temperature | °C |
| `thermostat_current_temperature_celsius` | Current avg temperature | °C |

## Multi-System Integration Guide

### Setup Order

**1. Install shelly-blu-ht** *(temperature sensors)*
```bash
cd ~/projects
git clone https://github.com/stephan-aichholzer/shelly-blu-ht.git
cd shelly-blu-ht
docker-compose up -d
# Creates shelly_bt_temp_default network
```

**2. Install heatpump-monitoring-dashboard** *(this project)*
```bash
cd ~/projects
git clone https://github.com/stephan-aichholzer/heatpump-monitoring-dashboard.git
cd heatpump-monitoring-dashboard
# Configure exporter/exporter.py with your meter settings
docker-compose up -d
# Creates heatpump_dashboard_default network
```

**3. Install lg-r290-control** *(heat pump)*
```bash
cd ~/projects
git clone https://github.com/stephan-aichholzer/lg-r290-control.git
cd lg-r290-control
# Configure with your heat pump settings
docker-compose up -d
# Connects to both networks
```

### Verify Integration

```bash
# Check networks exist
docker network ls | grep -E "shelly_bt_temp|heatpump_dashboard"

# Verify Prometheus targets
curl http://localhost:9090/api/v1/targets
# Should show: wago, temperature-sensors, heatpump (all UP)

# Test metrics
curl http://localhost:9090/api/v1/query?query=wago_power_total_kw
curl http://localhost:9090/api/v1/query?query=sensor_temperature_celsius
curl http://localhost:9090/api/v1/query?query=heatpump_flow_temperature_celsius
```

## Troubleshooting

### Energy Meter Issues

**No metrics**:
```bash
docker-compose logs modbus_exporter
curl http://localhost:9100/metrics
```

**Connection errors**:
- Verify `MODBUS_IP`, `MODBUS_PORT`, `SLAVE_ID` in `exporter/exporter.py`
- Test network: `ping <gateway-ip>`
- Test port: `telnet <gateway-ip> <port>`

**Wrong values**:
- Check register addresses match your meter's manual
- Verify data type (Float32 vs Int16, etc.)
- Check byte order (Big Endian default)

### Integration Issues

**Temperature sensors not visible**:
```bash
# Check network exists
docker network inspect shelly_bt_temp_default | grep prometheus

# Verify iot-api is reachable
docker exec heatpump_dashboard_prometheus curl http://iot-api:8000/metrics
```

**Heat pump metrics missing**:
```bash
# Check lg_r290_service is on network
docker network inspect heatpump_dashboard_default | grep lg_r290_service

# Test connectivity
docker exec heatpump_dashboard_prometheus curl http://lg_r290_service:8000/metrics
```

**After system reboot**:
- Auto-restart enabled: `restart: unless-stopped` in docker-compose.yml
- Start order: shelly-blu-ht → heatpump-dashboard → lg-r290-control

### Dashboard Issues

**No data in panels**:
- Check Prometheus is scraping: `http://localhost:9090/targets`
- Verify data source in Grafana points to `http://prometheus:9090`
- Check time range in dashboard (default: last 6 hours)

**Missing metrics**:
- Verify external services are running: `docker ps | grep -E "iot-api|lg_r290_service"`
- Check Prometheus scrape errors: `http://localhost:9090/targets`

## Version History

### v2.2 (Current)
- Power spike filtering
- Monotonic energy counter protection
- Heat pump service integration (lg-r290-control)
- Automated backup script

### v2.1
- IoT temperature sensor integration (shelly-blu-ht)
- Docker network multi-system support
- External API scraping

### v2.0
- Frequency and power factor monitoring
- Enhanced dashboard with KPIs
- Heat pump optimized thresholds

### v1.0
- Basic power and energy monitoring
- Simple Grafana dashboard

## Related Documentation

- **[README.md](README.md)** - Quick start guide
- **[lg-r290-control](https://github.com/stephan-aichholzer/lg-r290-control)** - Heat pump control & monitoring
- **[shelly-blu-ht](https://github.com/stephan-aichholzer/shelly-blu-ht)** - Temperature sensors & thermostat

---

**Technical deep-dive** • System architecture • Component specifications • Integration guide
