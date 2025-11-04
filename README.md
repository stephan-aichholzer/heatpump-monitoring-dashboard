# Heat Pump Monitoring Dashboard

A comprehensive monitoring solution for heating systems with integrated energy metering, temperature sensing, and heat pump control. Designed for professional-grade insights into your complete heating ecosystem with real-time metrics, historical analysis, and smart integrations.

**Perfect for small to medium heat pumps (up to 7kW) with 1-year data retention and 30-second granularity.**

## 🎯 What It Monitors

### Your Complete Heating System
- **⚡ Energy Consumption** - 3-phase power monitoring via Modbus energy meters (WAGO, Shelly, or compatible)
- **🌡️ Temperature Monitoring** - Indoor/outdoor temps via Shelly BLU sensors with thermostat integration
- **🔥 Heat Pump Status** - Real-time heat pump operation (LG R290 or compatible Modbus devices)
- **📊 Grid Quality** - Frequency stability and power factor for system health
- **🏠 Smart Integrations** - Shelly BLU sensors, Bluetooth gateways, IoT devices

## 🚀 Features

### Integrated Heating System Monitoring
This dashboard serves as your **central monitoring hub**, integrating data from multiple subsystems:

#### 1. Energy Metering (via Modbus)
- Real-time 3-phase power consumption (W/kW)
- Cumulative and daily energy tracking (kWh)
- Grid quality monitoring (frequency, power factor)
- Heat pump power pattern recognition (6W standby / 46W active)

#### 2. Heat Pump Monitoring ✨ *v2.2+*
Integration: [LG R290 Heat Pump Control](https://github.com/stephan-aichholzer/lg-r290-control)
- Flow/return water temperatures
- Compressor and pump status
- Operating mode tracking (Auto/Manual/Heating)
- Temperature delta calculations

#### 3. Temperature & Climate ✨ *v2.1+*
Integration: [Shelly BLU Sensors](https://github.com/stephan-aichholzer/shelly-blu-ht)
- Multi-zone temperature monitoring
- Humidity tracking
- Thermostat state and target temperatures
- Battery levels for wireless sensors

### Data Quality & Reliability ✨ *v2.2*
- **Power Spike Filtering** - Eliminates Modbus bus interference
- **Monotonic Energy Counters** - Prevents meter reset issues
- **Connection Resilience** - Auto-reconnect on network failures
- **1-Year Retention** - Long-term seasonal analysis

### Professional Dashboard
- **Unified View** - All heating system metrics in one Grafana interface
- **Color-Coded Alerts** - Heat pump optimized thresholds (0-1-2kW)
- **Cross-System Analytics** - Correlate energy usage with temperatures and heat pump operation
- **Standard Electrical Colors** - EU IEC 60446 (L1=Brown, L2=Black, L3=Grey)
- **30-Second Granularity** - Real-time monitoring with minimal latency

### Technical Specifications
- **Polling Interval**: 30 seconds
- **Data Retention**: 1 year (Prometheus)
- **Metrics Format**: Prometheus-compatible
- **Container Architecture**: Docker Compose with multi-network support
- **Extensible**: Modular design for custom integrations

## 📋 Prerequisites

### Hardware Requirements

**Core Components:**
- **3-phase Energy Meter** with Modbus support (tested with WAGO, adaptable to Shelly Pro 3EM or any Modbus meter)
- **Modbus Gateway** - RS485-to-TCP converter (Waveshare or compatible) if using RS485 meters, or direct TCP for Ethernet meters
- **Host System** - Raspberry Pi or any Docker-capable system (Linux/Windows/macOS)

**Optional Integrations** (for complete heating system monitoring):
- **Heat Pump** - LG R290 or any Modbus-compatible heat pump (see [lg-r290-control](https://github.com/stephan-aichholzer/lg-r290-control))
- **Temperature Sensors** - Shelly BLU H&T or compatible IoT sensors (see [shelly-blu-ht](https://github.com/stephan-aichholzer/shelly-blu-ht))
- **Bluetooth Gateway** - Shelly Pro 2 or compatible (for BLE sensors)

### Software Requirements
- Docker and Docker Compose
- Network connectivity to Modbus gateway
- Available ports: 3000 (Grafana), 9090 (Prometheus), 9100 (Exporter)

### Network Configuration
- **Modbus Gateway**: Configure your gateway IP and port in `exporter/exporter.py` (default: `192.168.2.10:8899`)
- **Slave ID**: Set your meter's Modbus slave ID (default: `2`)
- **External System Integration** (Optional): Complete heating ecosystem monitoring
  - Requires external Docker network: `shelly_bt_temp_default`
  - **Temperature sensors**: `iot-api:8000` from [shelly-blu-ht](https://github.com/stephan-aichholzer/shelly-blu-ht)
  - **Heat pump service**: `lg_r290_service:8000` from [lg-r290-control](https://github.com/stephan-aichholzer/lg-r290-control)

## 🔧 Installation

### 1. Clone Repository
```bash
git clone https://github.com/stephan-aichholzer/heatpump-monitoring-dashboard.git
cd heatpump-monitoring-dashboard
```

### 2. Configure Your Energy Meter
Edit `exporter/exporter.py` to match your Modbus gateway and meter settings:
```python
MODBUS_IP = "192.168.2.10"    # Your gateway IP
MODBUS_PORT = 8899            # Your gateway port
SLAVE_ID = 2                  # Your meter's Modbus slave ID
```

**Note**: For non-WAGO meters, you'll also need to update the register addresses. See the "Energy Meter Compatibility" section below.

### 3. Start Services
```bash
docker-compose up -d
```

### 4. Verify Operation
```bash
# Check all services are running
docker-compose ps

# Verify WAGO metrics collection
curl http://localhost:9100/metrics | grep wago

# Check for new grid quality metrics
curl http://localhost:9100/metrics | grep -E "frequency|power_factor"

# Verify temperature sensor integration (if available)
curl http://localhost:9090/api/v1/query?query=sensor_temperature_celsius
```

## 📊 Dashboard Setup

### 1. Access Grafana
Open your browser to: `http://localhost:3000`

**Default credentials:**
- Username: `admin`
- Password: `admin` (change on first login)

### 2. Import Dashboard
1. Go to **Dashboards** → **Import**
2. Upload `dashboards/heat_pump_dashboard.json`
3. Select your Prometheus data source
4. Click **Import**

### 3. Configure Data Source (if needed)
1. Go to **Configuration** → **Data Sources**
2. Add **Prometheus** data source
3. Set URL to: `http://prometheus:9090`
4. Click **Save & Test**

## 🔌 Energy Meter Compatibility

This system is designed to work with any **Modbus RTU or Modbus TCP** energy meter. The adapter (`exporter/exporter.py`) is currently configured for WAGO registers but can easily be adapted for other meters.

### Tested Hardware
- ✅ **WAGO Energy Meters** - 3-phase, Modbus RTU (current default implementation)
- 🔄 **Shelly Pro 3EM** - Adaptable (requires register mapping adjustment)
- 🔄 **Any Modbus meter** - Adaptable (requires register mapping adjustment)

### Adapting to Your Energy Meter

The default implementation uses WAGO register addresses. To adapt for your meter:

**1. Find your meter's Modbus register map** (usually in the device manual or datasheet)

**2. Update register addresses** in `exporter/exporter.py` (lines 128-140):

```python
# Current WAGO implementation:
power = await read_float32(client, 0x5012)     # Total power register
energy = await read_float32(client, 0x6000)    # Total energy register
power_l1 = await read_float32(client, 0x5014)  # L1 power register
# ... etc

# Example for another meter (check your manual):
# power = await read_float32(client, 0x0000)   # Your meter's power register
# energy = await read_float32(client, 0x0010)  # Your meter's energy register
```

**3. Update connection parameters** in `exporter/exporter.py` (lines 45-47):

```python
MODBUS_IP = "192.168.2.10"    # Your gateway/meter IP
MODBUS_PORT = 8899            # Your gateway/meter port
SLAVE_ID = 2                  # Your meter's Modbus slave ID
```

**4. Test the connection:**

```bash
# Rebuild and restart
docker-compose build modbus_exporter
docker-compose up -d modbus_exporter

# Check metrics are being collected
curl http://localhost:9100/metrics | grep wago_power
```

### Register Mapping Reference

The exporter reads these metrics (WAGO addresses shown, adjust for your meter):

| Metric Type | WAGO Register | Description | Data Type |
|-------------|---------------|-------------|-----------|
| Total Power | 0x5012 | Combined 3-phase power | Float32 |
| L1 Power | 0x5014 | Phase 1 power | Float32 |
| L2 Power | 0x5016 | Phase 2 power | Float32 |
| L3 Power | 0x5018 | Phase 3 power | Float32 |
| Frequency | 0x5008 | Grid frequency | Float32 |
| Power Factor | 0x502A | Power factor (Cos φ) | Float32 |
| Total Energy | 0x6000 | Cumulative energy | Float32 |
| L1 Energy | 0x6006 | Phase 1 cumulative | Float32 |
| L2 Energy | 0x6008 | Phase 2 cumulative | Float32 |
| L3 Energy | 0x600A | Phase 3 cumulative | Float32 |

### Contributing Adapters
Have another meter working? Please contribute your adapter configuration via pull request! We'd love to expand hardware support.

## 📈 Monitoring Metrics

### Energy Metering Metrics
*Source: Modbus energy meter (default implementation: WAGO)*

**Power Metrics:**
| Metric | Description | Unit | Example |
|--------|-------------|------|---------|
| `wago_power_total_kw` | Total active power | kW | 0.046 (46W) |
| `wago_power_L1_kw` | L1 phase power | kW | 0.046 |
| `wago_power_L2_kw` | L2 phase power | kW | 0.000 |
| `wago_power_L3_kw` | L3 phase power | kW | 0.000 |

**Energy Metrics:**
| Metric | Description | Unit | Example |
|--------|-------------|------|---------|
| `wago_energy_total_kwh` | Total cumulative energy | kWh | 87.33 |
| `wago_energy_L1_kwh` | L1 cumulative energy | kWh | 39.98 |
| `wago_energy_L2_kwh` | L2 cumulative energy | kWh | 24.64 |
| `wago_energy_L3_kwh` | L3 cumulative energy | kWh | 21.57 |

**Grid Quality Metrics:** ✨ *v2.0+*
| Metric | Description | Unit | Example |
|--------|-------------|------|---------|
| `wago_frequency_hz` | Grid frequency | Hz | 49.98 |
| `wago_power_factor` | Power factor (Cos φ) | ratio | 0.240 |

### Heat Pump Metrics ✨ *v2.2+*
*Source: [lg-r290-control](https://github.com/stephan-aichholzer/lg-r290-control) - LG R290 7kW heat pump (optional integration)*

| Metric | Description | Unit | Example |
|--------|-------------|------|---------|
| `heatpump_flow_temperature_celsius` | Flow temperature (water outlet) | °C | 35.2 |
| `heatpump_return_temperature_celsius` | Return temperature (water inlet) | °C | 32.8 |
| `heatpump_outdoor_temperature_celsius` | Outdoor air temperature | °C | 5.3 |
| `heatpump_target_temperature_celsius` | Target temperature setpoint | °C | 40.0 |
| `heatpump_power_state` | Power state (0=OFF, 1=ON) | boolean | 1 |
| `heatpump_compressor_running` | Compressor running (0=OFF, 1=ON) | boolean | 1 |
| `heatpump_water_pump_running` | Water pump running (0=OFF, 1=ON) | boolean | 1 |
| `heatpump_operating_mode` | Operating mode (0=Standby, 1=Cooling, 2=Heating, 3=Auto) | enum | 3 |
| `heatpump_temperature_delta_celsius` | Temperature delta (flow - return) | °C | 2.4 |

### Temperature & Climate Metrics ✨ *v2.1+*
*Source: [shelly-blu-ht](https://github.com/stephan-aichholzer/shelly-blu-ht) - Shelly BLU H&T sensors with thermostat (optional integration)*

| Metric | Description | Unit | Example |
|--------|-------------|------|---------|
| `sensor_temperature_celsius` | Temperature readings | °C | 22.5 |
| `sensor_humidity_percent` | Humidity readings | % | 45.2 |
| `sensor_battery_percent` | Battery level | % | 85 |
| `sensor_last_seen_timestamp` | Last sensor update | timestamp | 1759050278 |
| `thermostat_switch_state` | Thermostat state (0=OFF, 1=ON) | boolean | 1 |
| `thermostat_target_temperature_celsius` | Target temperature setpoint | °C | 22.0 |
| `thermostat_current_temperature_celsius` | Current averaged temperature | °C | 21.5 |

## 🎯 Heat Pump Monitoring

### Power Consumption Patterns
- **6W**: Standby mode (controls, sensors)
- **46W**: Active operation (40W pump + 6W base)
- **>2000W**: High load/defrost cycle

### Grid Quality Indicators
- **Frequency**: 49.8-50.2 Hz (green), outside = yellow/red
- **Power Factor**: >0.85 (green), 0.7-0.85 (yellow), <0.7 (red)

### Dashboard Color Coding
- 🟢 **Green**: Normal operation (0-1kW, 49.8-50.2Hz, PF>0.85)
- 🟡 **Yellow**: Moderate load (1-2kW, frequency ±0.3Hz, PF 0.7-0.85)
- 🔴 **Red**: High load/alert (>2kW, frequency ±0.5Hz, PF<0.7)

## 🛠 Troubleshooting

### Service Issues
```bash
# Check container logs
docker-compose logs

# Restart specific service
docker-compose restart heatpump_dashboard_modbus_exporter

# Check service status
docker-compose ps
```

### Connectivity Issues
```bash
# Test Modbus gateway connectivity
ping 192.168.2.10
telnet 192.168.2.10 8899

# Check metrics endpoint
curl http://localhost:9100/metrics | head -20

# Verify new metrics
curl http://localhost:9100/metrics | grep -E "wago_(frequency|power_factor)"
```

### External System Integration Issues ✨ *New in v2.1+*
```bash
# Check temperature sensor API (shelly-blu-ht project)
curl http://192.168.2.11:8001/api/v1/sensors
curl http://192.168.2.11:8001/metrics | grep sensor_temperature

# Check heat pump service API (lg-r290-control project)
curl http://192.168.2.11:8002/status
curl http://192.168.2.11:8002/metrics | grep heatpump

# Verify Prometheus is scraping all targets
curl http://localhost:9090/api/v1/query?query=sensor_temperature_celsius
curl http://localhost:9090/api/v1/query?query=heatpump_flow_temperature_celsius
```

### Common Issues
1. **No data in dashboard**: Check Prometheus is scraping metrics
2. **Connection timeouts**: Verify Modbus gateway/meter IP and port in `exporter/exporter.py`
3. **Missing frequency/power factor**: Ensure your energy meter supports these registers (check meter manual)
4. **Wrong values**: Verify Modbus slave ID configuration matches your meter
5. **Register read errors**: Update register addresses in `exporter/exporter.py` to match your meter's Modbus map
6. **Temperature data stuck**: Check metrics endpoint reflects latest API values
7. **Container unhealthy**: Restart temperature sensor container with `docker restart iot-api`
8. **Power spikes/garbage values**: v2.2+ includes automatic spike filtering (requires 2 consecutive low readings)
9. **Energy counter resets**: v2.2+ includes monotonic counter protection to prevent backward jumps

## 📁 Project Structure

```
.
├── docker-compose.yml              # Service orchestration
├── exporter/                       # Modbus data collector
│   ├── Dockerfile                  # Container definition
│   └── exporter.py                 # Main collection script (with spike filtering)
├── prometheus/                     # Time series database
│   └── prometheus.yml              # Scraping configuration
├── dashboards/                     # Grafana dashboards
│   └── heat_pump_dashboard.json    # Main dashboard
├── backup.sh                       # Automated backup script
├── ARCHITECTURE.md                 # Technical architecture
└── README.md                       # This file
```

## 🔄 Data Flow

```
WAGO Energy Meter → RS485 → Waveshare Gateway → TCP/IP → Modbus Exporter → Prometheus → Grafana
```

## 📦 Backup & Maintenance

### Automated Backup ✨ *New in v2.2*
```bash
# Run comprehensive backup (includes Git repo, Docker volumes, Grafana dashboards)
./backup.sh

# Or specify custom filename
./backup.sh --output my_backup_2025.tar.gz

# Backup includes:
# - Git repository with current branch and uncommitted changes
# - Prometheus data volume
# - Grafana data volume
# - Grafana dashboards exported via API
# - Backup metadata with timestamps
```

### Manual Backup (Legacy)
```bash
# Backup Prometheus data only
docker run --rm -v heatpump_dashboard_prometheus_data:/data \
  -v $(pwd):/backup alpine tar czf /backup/prometheus_backup.tar.gz -C /data .

# Backup Grafana data only
docker run --rm -v heatpump_dashboard_grafana_data:/data \
  -v $(pwd):/backup alpine tar czf /backup/grafana_backup.tar.gz -C /data .
```

### Update Services
```bash
# Pull latest images
docker-compose pull

# Restart with new images
docker-compose up -d
```

## 🏷 Version History

### v2.2 (Current)
- ✅ Power spike filtering to eliminate bus interference
- ✅ Monotonic energy counter protection
- ✅ Heat pump service integration (LG R290)
- ✅ Comprehensive automated backup script
- ✅ Enhanced data quality and resilience

### v2.1
- ✅ Integrated IoT temperature sensor monitoring
- ✅ Added Docker network configuration for external sensors
- ✅ Temperature, humidity, and battery metrics support
- ✅ Prometheus scraping of external APIs
- ✅ Enhanced monitoring ecosystem

### v2.0
- ✅ Added frequency monitoring (WAGO register 0x5008)
- ✅ Added power factor monitoring (WAGO register 0x502A)
- ✅ Enhanced dashboard with real-time KPIs
- ✅ Heat pump optimized thresholds
- ✅ Grid quality monitoring
- ✅ Improved unit display (Watts)

### v1.0
- Basic power and energy monitoring
- Simple Grafana dashboard
- Docker Compose deployment

## 🔗 Related Projects

This project is part of a complete heating system monitoring and control ecosystem:

### [LG R290 Heat Pump Control](https://github.com/stephan-aichholzer/lg-r290-control)
Docker-based control system for LG R290 7kW heat pump via Modbus TCP:
- FastAPI backend with Prometheus metrics export
- Responsive web UI with dark mode
- LG Auto mode with offset adjustment
- Manual heating mode with direct temperature control
- Thermostat integration for automated comfort control

**Integration**: Connected via Docker network (`heatpump_dashboard_default`). The heatpump_dashboard Prometheus instance scrapes real-time heat pump metrics (flow/return temps, compressor status, operating mode) from the control service.

### [Shelly BLU Temperature Monitoring & Thermostat](https://github.com/stephan-aichholzer/shelly-blu-ht)
IoT monitoring stack with intelligent thermostat control:
- Shelly Pro 2 as Bluetooth gateway and switch controller
- Shelly BLU H&T sensors for temperature/humidity measurement
- FastAPI backend with InfluxDB storage
- Intelligent thermostat with temperature averaging
- 4 operating modes: AUTO, ECO, ON, OFF

**Integration**: Connected via Docker network (`shelly_bt_temp_default`). The heatpump_dashboard Prometheus instance scrapes temperature, humidity, battery, and thermostat state metrics from the sensor API.

### Architecture Overview
```
┌─────────────────────────────────────────────────────────────────┐
│                    Complete Heating Ecosystem                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐      ┌──────────────────┐               │
│  │  Shelly BLU H&T  │      │  LG R290 Heat    │               │
│  │  Sensors         │      │  Pump            │               │
│  │  (shelly-blu-ht) │      │  (lg-r290-       │               │
│  │                  │      │   control)       │               │
│  │  • Temp sensors  │      │  • Modbus TCP    │               │
│  │  • Thermostat    │      │  • Flow/Return   │               │
│  │  • Switch control│──────│  • Auto/Manual   │               │
│  └──────────────────┘      └──────────────────┘               │
│           │                         │                          │
│           │                         │                          │
│           └─────────────┬───────────┘                          │
│                         │                                      │
│              ┌──────────▼───────────┐                          │
│              │  WAGO Energy Meter   │                          │
│              │  (heatpump_dashboard)│                          │
│              │                      │                          │
│              │  • Power monitoring  │                          │
│              │  • Grid quality      │                          │
│              │  • Central metrics   │                          │
│              │  • Prometheus + Graf │                          │
│              └──────────────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Third-Party Dependencies

This project uses the following open source software:

- **pymodbus** (v3.6.9) - BSD-3-Clause License
- **prometheus_client** - Apache-2.0 License
- **Prometheus** - Apache-2.0 License
- **Grafana** - AGPL-3.0 License

For detailed license information and attributions, see the [NOTICE](NOTICE) file.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review container logs: `docker-compose logs`
3. Open an issue on GitHub with system details and logs

---

**Perfect for small heat pump monitoring with professional-grade insights! 🎯**