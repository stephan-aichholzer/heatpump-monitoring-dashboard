# Heat Pump Monitoring Dashboard - Architecture

## Overview

This project implements a comprehensive heating system monitoring platform with integrated energy metering, heat pump monitoring, and temperature sensing. The entire monitoring stack runs on a Raspberry Pi (or any Docker-capable host) using containerized services with Prometheus time-series storage and Grafana visualization.

**Current Version: v2.2** - Enhanced with power spike filtering, monotonic energy counter protection, heat pump integration, and automated backup capabilities.

## System Purpose

This project has evolved from a simple energy meter reader into a **comprehensive heating system monitoring platform**. It now serves as the central data collection and visualization hub for:

1. **Energy metering** - Modbus-based power/energy monitoring (WAGO implementation, adaptable to Shelly Pro 3EM or any Modbus meter)
2. **Heat pump control & monitoring** - Real-time heat pump status and performance metrics
3. **Temperature sensing** - Multi-zone climate monitoring with smart thermostat integration
4. **Unified analytics** - Cross-system correlation and insights for complete heating system visibility

The architecture is **modular and extensible** - you can use just the energy monitoring component or integrate the complete heating ecosystem.

## Integrated System Components

This dashboard serves as the **central monitoring hub** for a complete heating system ecosystem, integrating metrics from:

1. **Energy Metering** (this project) - 3-phase power and energy monitoring
   - Power consumption monitoring (6W standby / 46W active)
   - Grid quality metrics (frequency, power factor)
   - Centralized Prometheus + Grafana dashboard
   - Default: WAGO energy meter (adaptable to other Modbus meters)

2. **[LG R290 Heat Pump Control](https://github.com/stephan-aichholzer/lg-r290-control)** - LG R290 7kW heat pump Modbus TCP control (optional integration)
   - Real-time heat pump status (flow/return temps, compressor state)
   - Operating mode monitoring (Auto/Manual heating)
   - Connected via Docker network: `heatpump_dashboard_default`

3. **[Shelly BLU Temperature Monitoring & Thermostat](https://github.com/stephan-aichholzer/shelly-blu-ht)** - IoT sensor monitoring with thermostat (optional integration)
   - Temperature/humidity from Shelly BLU H&T sensors
   - Thermostat control state and target temperatures
   - Connected via Docker network: `shelly_bt_temp_default`

## Physical Architecture

### Complete Heating Ecosystem

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Complete Heating System                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐              ┌──────────────────┐
│  Shelly BLU H&T  │              │  LG R290 Heat    │
│  Sensors         │              │  Pump (7kW)      │
│  (Bluetooth)     │              │  (Modbus RTU)    │
└────────┬─────────┘              └────────┬─────────┘
         │                                 │
         │ BT                             │ RS485
         ▼                                 ▼
┌──────────────────┐              ┌──────────────────┐          ┌─────────────────┐
│  Shelly Pro 2    │              │  Waveshare       │          │  Energy Meter   │
│  (BT Gateway +   │              │  RS485-to-ETH    │          │  (Modbus RTU)   │
│   Switch)        │              │  Gateway         │◄─────────│   3-phase       │
└────────┬─────────┘              └────────┬─────────┘  RS485   └─────────────────┘
         │                                 │
         │ Ethernet                        │ Ethernet (Modbus TCP)
         │                                 │
         └──────────────────┬──────────────┘
                            │
                            ▼
         ┌─────────────────────────────────────────────┐
         │        Raspberry Pi Host System             │
         │                                             │
         │  ┌─────────────────────────────────────┐   │
         │  │  shelly-blu-ht Stack                │   │
         │  │  (shelly_bt_temp_default network)   │   │
         │  │  ┌─────────────────────────────┐    │   │
         │  │  │  iot-api:8000 (FastAPI)     │    │   │
         │  │  │  • Sensor polling           │    │   │
         │  │  │  • Thermostat control       │    │   │
         │  │  │  • Prometheus metrics       │    │   │
         │  │  └─────────────────────────────┘    │   │
         │  └─────────────────────────────────────┘   │
         │                                             │
         │  ┌─────────────────────────────────────┐   │
         │  │  lg-r290-control Stack              │   │
         │  │  (heatpump_dashboard_default net)   │   │
         │  │  ┌─────────────────────────────┐    │   │
         │  │  │  lg_r290_service:8000       │    │   │
         │  │  │  • Modbus TCP control       │    │   │
         │  │  │  • Heat pump monitoring     │    │   │
         │  │  │  • Prometheus metrics       │    │   │
         │  │  └─────────────────────────────┘    │   │
         │  └─────────────────────────────────────┘   │
         │                                             │
         │  ┌─────────────────────────────────────┐   │
         │  │  heatpump_dashboard Stack (THIS)    │   │
         │  │  ┌─────────────────────────────┐    │   │
         │  │  │  modbus_exporter:9100       │    │   │
         │  │  │  • WAGO polling             │    │   │
         │  │  └─────────────────────────────┘    │   │
         │  │  ┌─────────────────────────────┐    │   │
         │  │  │  prometheus:9090            │    │   │
         │  │  │  • Scrapes all metrics:     │    │   │
         │  │  │    - WAGO energy            │    │   │
         │  │  │    - Temperature sensors    │◄───┼───┼── Scrapes
         │  │  │    - Heat pump status       │    │   │   external
         │  │  └─────────────────────────────┘    │   │   APIs
         │  │  ┌─────────────────────────────┐    │   │
         │  │  │  grafana:3000               │    │   │
         │  │  │  • Central dashboard        │    │   │
         │  │  │  • Unified visualization    │    │   │
         │  │  └─────────────────────────────┘    │   │
         │  └─────────────────────────────────────┘   │
         └─────────────────────────────────────────────┘
```

### Individual System: Energy Meter Monitoring

```
┌─────────────────┐    RS485/   ┌──────────────────┐    Ethernet    ┌─────────────────────────┐
│  Energy Meter   │◄──Modbus──►│   Modbus Gateway │◄──────────────►│    Raspberry Pi         │
│  (3-phase)      │    RTU      │   (if RS485)     │                │    Host System          │
│  Modbus slave   │             │   or direct TCP  │                │                         │
└─────────────────┘             │   192.168.x.x    │                │  ┌─────────────────────┐│
                                │   Port: 8899     │                │  │  Docker Containers  ││
                                └──────────────────┘                │  │                     ││
                                                                    │  │  ┌─────────────────┐││
                                                                    │  │  │ Modbus Exporter │││
                                                                    │  │  │     :9100       │││
                                                                    │  │  └─────────────────┘││
                                                                    │  │  ┌─────────────────┐││
                                                                    │  │  │   Prometheus    │││
                                                                    │  │  │     :9090       │││
                                                                    │  │  │   (Data Store)  │││
                                                                    │  │  └─────────────────┘││
                                                                    │  │  ┌─────────────────┐││
                                                                    │  │  │    Grafana      │││
                                                                    │  │  │     :3000       │││
                                                                    │  │  │   (Dashboard)   │││
                                                                    │  │  └─────────────────┘││
                                                                    │  └─────────────────────┘│
                                                                    │                         │
                                                                    │  ┌─────────────────────┐│
                                                                    │  │  Persistent Storage ││
                                                                    │  │                     ││
                                                                    │  │  prometheus_data/   ││
                                                                    │  │  grafana_data/      ││
                                                                    │  └─────────────────────┘│
                                                                    └─────────────────────────┘
```

### Hardware Components

1. **Energy Meter (3-phase Modbus)**
   - 3-phase electrical energy measurement device
   - Modbus RTU or Modbus TCP protocol
   - Default implementation: WAGO (adaptable to Shelly Pro 3EM, or any Modbus meter)
   - Connected via RS485 or Ethernet

2. **Modbus Gateway (if using RS485)**
   - Converts RS485 Modbus RTU to TCP/IP
   - Example: Waveshare RS485-to-Ethernet adapter
   - Configurable IP/port (default example: `192.168.2.10:8899`)
   - Not needed for direct Modbus TCP meters

3. **Raspberry Pi Host System (or any Docker-capable host)**
   - Runs Docker Engine
   - Hosts all monitoring containers
   - Provides persistent data storage
   - Network access point for users

## Software Architecture

### Raspberry Pi Docker Stack

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Raspberry Pi Host                             │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                      Docker Compose                                ││
│  │                                                                     ││
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐ ││
│  │  │   Modbus        │  │   Prometheus    │  │      Grafana        │ ││
│  │  │   Exporter      │──│   Time Series   │──│     Dashboard       │ ││
│  │  │   Container     │  │   Database      │  │     Interface       │ ││
│  │  │   Port: 9100    │  │   Port: 9090    │  │     Port: 3000      │ ││
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────┘ ││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                    Persistent Storage                               ││
│  │                                                                     ││
│  │  ┌─────────────────┐              ┌─────────────────────────────────┐││
│  │  │ prometheus_data │              │         grafana_data            │││
│  │  │                 │              │                                 │││
│  │  │ • Metrics TSDB  │              │ • Dashboard configs             │││
│  │  │ • 1 year retain │              │ • User settings                 │││
│  │  │ • Query engine  │              │ • Data sources                  │││
│  │  └─────────────────┘              └─────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

#### Complete Ecosystem Data Flow
```
┌──────────────────────────────────────────────────────────────────────────┐
│                         Data Collection                                  │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Shelly BLU Sensors → Shelly Pro 2 → iot-api:8000 ──┐                  │
│  (Bluetooth)          (HTTP Poll)    (Prometheus)    │                  │
│                                                       │                  │
│  LG R290 Heat Pump → Waveshare → lg_r290_service ───┼─────┐            │
│  (Modbus RTU)        (TCP)       (Prometheus)        │     │            │
│                                                       │     │            │
│  Energy Meter → Modbus Gateway → modbus_exporter ───┘     │            │
│  (Modbus RTU)   (RS485→TCP)      (Prometheus)              │            │
│                                                             │            │
└─────────────────────────────────────────────────────────────┼────────────┘
                                                              │
                                                              ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                     Central Monitoring & Storage                         │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│               prometheus:9090 (heatpump_dashboard)                       │
│               ┌────────────────────────────────┐                         │
│               │  Scrape Targets (30s):        │                         │
│               │  • modbus_exporter:9100        │  (Energy meter)        │
│               │  • iot-api:8000/metrics        │  (Temp sensors)        │
│               │  • lg_r290_service:8000/metrics│  (Heat pump status)    │
│               └────────────────────────────────┘                         │
│                           │                                              │
│                           │ Query                                        │
│                           ▼                                              │
│               ┌────────────────────────────────┐                         │
│               │  grafana:3000                  │                         │
│               │  • Unified dashboard           │                         │
│               │  • Cross-system visualization  │                         │
│               │  • 1-year data retention       │                         │
│               └────────────────────────────────┘                         │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

#### Individual System: Energy Meter Monitoring
```
Energy Meter → RS485/Modbus → Gateway (if RS485) → Network → Raspberry Pi → Modbus Exporter → Prometheus → Grafana
               RTU/TCP        TCP adapter         (LAN)     (Docker Host)   (Container)       (Container)   (Container)
```

## Component Details

### 1. Modbus Exporter Container (`exporter/exporter.py`)

**Purpose**: Polls the energy meter via Modbus (RTU/TCP) and exposes Prometheus metrics

**Runtime Environment**:
- Docker container on Raspberry Pi
- Python 3.12-slim base image
- Network access to Waveshare gateway

**Key Features**:
- Asynchronous Modbus TCP client
- 30-second polling interval
- Error handling and logging
- Prometheus metrics exposition on port 9100
- **Power spike filtering** ✨ *v2.2* - Filters out bus interference and garbage values
- **Monotonic energy counter** ✨ *v2.2* - Prevents backward energy counter jumps
- **Connection resilience** ✨ *v2.2* - Automatic reconnection on connection loss

**Monitored Registers (WAGO default, adaptable to other meters)**:
| Metric | WAGO Register | Description |
|--------|---------------|-------------|
| Total Power | `0x5012` | Total active power (kW) |
| L1 Power | `0x5014` | L1 phase active power (kW) |
| L2 Power | `0x5016` | L2 phase active power (kW) |
| L3 Power | `0x5018` | L3 phase active power (kW) |
| **Frequency** ✨ | `0x5008` | **Grid frequency (Hz)** |
| **Power Factor** ✨ | `0x502A` | **Power factor (Cos φ)** |
| Total Energy | `0x6000` | Total active energy (kWh) |
| L1 Energy | `0x6006` | L1 phase active energy (kWh) |
| L2 Energy | `0x6008` | L2 phase active energy (kWh) |
| L3 Energy | `0x600A` | L3 phase active energy (kWh) |

✨ *New in v2.0* - Enhanced grid quality monitoring for heat pump systems

**Note**: Register addresses are specific to WAGO meters. For other meters (Shelly Pro 3EM, etc.), update these addresses in `exporter/exporter.py` to match your meter's Modbus register map.

**Prometheus Metrics Exposed**:
- `wago_power_total_kw` - Total active power (kW)
- `wago_power_L1_kw`, `wago_power_L2_kw`, `wago_power_L3_kw` - Per-phase power (kW)
- `wago_energy_total_kwh` - Total cumulative energy (kWh)
- `wago_energy_L1_kwh`, `wago_energy_L2_kwh`, `wago_energy_L3_kwh` - Per-phase energy (kWh)
- **`wago_frequency_hz`** ✨ - Grid frequency (Hz)
- **`wago_power_factor`** ✨ - Power factor (Cos φ)

### 2. Prometheus Container

**Purpose**: Central time-series database running on Raspberry Pi

**Storage**:
- Data stored in `prometheus_data/` volume on Raspberry Pi filesystem
- 1-year retention policy
- Automatic data compaction

**Configuration**:
- Scrape interval: 30 seconds
- **Scrape targets** (multi-system integration):

  1. **Energy Meter** (internal network)
     - Target: `modbus_exporter:9100`
     - Metrics: Power, energy, frequency, power factor
     - Source: WAGO (default), adaptable to any Modbus meter
     - Network: `heatpump_dashboard_default`

  2. **Temperature Sensors** (external network) ✨ *v2.1+*
     - Target: `iot-api:8000/metrics`
     - Source: [shelly-blu-ht project](https://github.com/stephan-aichholzer/shelly-blu-ht)
     - Metrics: Temperature, humidity, battery, thermostat state
     - Network: `shelly_bt_temp_default`

  3. **Heat Pump Control** (external network) ✨ *v2.2+*
     - Target: `lg_r290_service:8000/metrics`
     - Source: [lg-r290-control project](https://github.com/stephan-aichholzer/lg-r290-control)
     - Metrics: Flow/return temps, compressor state, operating mode
     - Network: `heatpump_dashboard_default`

- Web interface: `http://raspberry-pi-ip:9090`

### 3. Grafana Container

**Purpose**: Dashboard interface running on Raspberry Pi

**Storage**:
- Configuration stored in `grafana_data/` volume on Raspberry Pi filesystem
- Persistent dashboards and user settings

**Features**:
- Web interface: `http://raspberry-pi-ip:3000`
- **Professional heat pump dashboard** ✨ (`dashboards/heat_pump_dashboard.json`)
- **Real-time KPIs**: Current power, frequency, power factor, daily energy
- **Live monitoring**: 6W standby / 46W active power detection
- **Grid quality**: Frequency stability and power factor trends
- **Color-coded alerts**: Heat pump optimized thresholds (0-1-2kW)
- Historical energy usage trends with phase analysis
- Standard electrical colors (L1=Brown, L2=Black, L3=Grey per EU IEC 60446)

## Network Configuration

### External Access
- **Grafana Dashboard**: `http://[raspberry-pi-ip]:3000`
- **Prometheus Interface**: `http://[raspberry-pi-ip]:9090`
- **Energy Meter Metrics Endpoint**: `http://[raspberry-pi-ip]:9100/metrics`
- **Temperature Sensor API**: `http://[raspberry-pi-ip]:8001` (shelly-blu-ht)
- **Heat Pump Control**: `http://[raspberry-pi-ip]:8002` (lg-r290-control)
- **Heat Pump UI**: `http://[raspberry-pi-ip]:8080` (lg-r290-control)

### Docker Network Configuration

**Network Topology**:
```
┌─────────────────────────────────────────────────────────────────┐
│  Docker Networks on Raspberry Pi                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────────┐                │
│  │  shelly_bt_temp_default (external)         │                │
│  │  • iot-api (Shelly BLU sensors)            │                │
│  │  • prometheus (scrapes metrics)            │                │
│  │  • grafana (queries data)                  │                │
│  │  • lg_r290_service (reads thermostat mode) │                │
│  └────────────────────────────────────────────┘                │
│                                                                 │
│  ┌────────────────────────────────────────────┐                │
│  │  heatpump_dashboard_default (internal)     │                │
│  │  • modbus_exporter (energy meter polling)  │                │
│  │  • prometheus (scrapes metrics)            │                │
│  │  • grafana (queries data)                  │                │
│  │  • lg_r290_service (heat pump control)     │                │
│  └────────────────────────────────────────────┘                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Network Details**:
1. **`heatpump_dashboard_default`** (internal network)
   - Created by heatpump_dashboard docker-compose
   - Connects: modbus_exporter, prometheus, grafana
   - Also used by lg-r290-control for integration

2. **`shelly_bt_temp_default`** (external network)
   - Created by shelly-blu-ht docker-compose
   - Connected to by: prometheus, grafana (for scraping sensor metrics)
   - Enables temperature sensor integration

### Internal Communication
- **Modbus Gateway**: `192.168.2.10:8899` (external to Raspberry Pi)
- **Container Network**: Docker internal networking between containers
- **Cross-Project**: External Docker networks enable multi-stack integration

### Modbus Parameters
- **Protocol**: Modbus TCP
- **Slave ID**: `2`
- **Data Format**: 32-bit IEEE 754 floats (Big Endian)

## Raspberry Pi Resources

### Storage Requirements
- **Application**: ~500MB (Docker images)
- **Prometheus Data**: ~100MB/month (depends on retention)
- **Grafana Data**: ~10MB (dashboards and config)

### System Services
- Docker Engine
- Docker Compose
- Network connectivity to Waveshare gateway

## Deployment on Raspberry Pi

### Prerequisites
```bash
# Ensure Docker is installed
sudo apt update
sudo apt install docker.io docker-compose

# Add user to docker group
sudo usermod -aG docker $USER
```

### Startup
```bash
cd /home/stephan/modbus
docker-compose up -d
```

### Monitoring
```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs

# Resource usage
docker stats
```

## Data Persistence and Backup

All data is stored locally on the Raspberry Pi:

### Critical Data Locations
- `/var/lib/docker/volumes/modbus_prometheus_data/` - Time series metrics
- `/var/lib/docker/volumes/modbus_grafana_data/` - Dashboard configurations

### Backup Strategy

**Automated Backup Script** ✨ *v2.2*
```bash
# Comprehensive backup including Git repo, volumes, and dashboards
./backup.sh

# Output: backup_YYYYMMDD_HHMMSS.tar.gz
```

**Manual Backup (Legacy)**
```bash
# Backup Prometheus data
docker run --rm -v modbus_prometheus_data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus_backup.tar.gz -C /data .

# Backup Grafana data
docker run --rm -v modbus_grafana_data:/data -v $(pwd):/backup alpine tar czf /backup/grafana_backup.tar.gz -C /data .
```

## Data Quality Features ✨ *v2.2*

### Power Spike Filtering

The exporter includes intelligent power value validation to filter out Modbus bus interference:

**Strategy**:
- Values < 1W (0.001 kW) are considered suspicious (e.g., `3.67e-27` from bus errors)
- Single suspicious values are ignored (spike filtering)
- Requires 2+ consecutive low readings to accept as real (system idle detection)

**Implementation**:
- Tracks last 3 power readings per metric (total, L1, L2, L3)
- Validates each new reading against history
- Logs warnings when rejecting garbage values
- Maintains last valid value during transient spikes

### Monotonic Energy Counter Protection

Prevents backward energy counter jumps caused by meter resets or communication errors:

**Strategy**:
- Energy values must always increase (monotonic)
- Rejects any reading lower than the last valid value
- Logs warnings when detecting backward jumps
- Maintains last valid energy value to ensure data continuity

**Benefits**:
- Accurate long-term energy consumption tracking
- Prevents negative energy calculations in Grafana
- Resilient to meter restarts and Modbus communication errors

### Connection Resilience

Automatic reconnection handling for Modbus TCP connectivity:

**Features**:
- Detects connection failures automatically
- Attempts reconnection on next polling cycle
- Maintains metric state during disconnections
- Logs connection status changes

## Heat Pump Monitoring Features ✨ *v2.0*

### Dashboard Overview
The enhanced dashboard provides comprehensive heat pump monitoring with professional-grade insights:

**Top Row - Live KPIs:**
- **Current Power**: Real-time consumption with color coding (6W standby / 46W active)
- **Grid Frequency**: Stability monitoring (49.8-50.2 Hz green zone)
- **Power Factor**: Heat pump efficiency indicator (Cos φ)
- **Today's Energy**: Daily consumption tracking

**Main Visualization Panels:**
- **Power Consumption**: Time series with L1/L2/L3 breakdown
- **Cumulative Energy**: Total kWh consumption over time
- **Daily Energy per Phase**: Bar chart showing load distribution
- **Grid Quality**: Frequency and power factor trends

### Heat Pump Specific Monitoring

**Power Consumption Patterns:**
- **6W**: Standby mode (control electronics, sensors)
- **46W**: Active operation (40W circulation pump + 6W base load)
- **>2kW**: High load operation or defrost cycles

**Grid Quality Indicators:**
- **Frequency Monitoring**: Detects grid instability affecting heat pump operation
- **Power Factor Tracking**: Monitors system efficiency and electrical health
- **Phase Balance**: Ensures proper 3-phase load distribution

**Color-Coded Thresholds:**
- 🟢 **Green**: Normal operation (0-1kW, 49.8-50.2Hz, PF>0.85)
- 🟡 **Yellow**: Moderate load (1-2kW, frequency ±0.3Hz, PF 0.7-0.85)
- 🔴 **Red**: High load/alert (>2kW, frequency ±0.5Hz, PF<0.7)

### Dashboard Location
The production dashboard is available at: `dashboards/heat_pump_dashboard.json`

Import this file into Grafana for complete heat pump monitoring with optimized thresholds and professional visualization.

## Troubleshooting

### System Health Checks
```bash
# Check Raspberry Pi resources
df -h
free -h
docker system df

# Test connectivity to Waveshare gateway
ping 192.168.2.10
telnet 192.168.2.10 8899
```

### Container Debugging
```bash
# Check individual container logs
docker-compose logs modbus_exporter
docker-compose logs prometheus
docker-compose logs grafana

# Access container shell
docker-compose exec modbus_exporter /bin/bash
```

## Multi-System Integration Guide

### Setting Up the Complete Ecosystem

This project integrates with two external systems to provide comprehensive heating system monitoring. Here's how to set up the complete stack:

#### 1. Prerequisites

All three projects should be cloned on the same Raspberry Pi:

```bash
cd ~/projects
git clone https://github.com/stephan-aichholzer/shelly-blu-ht.git shelly_bt_temp
git clone https://github.com/stephan-aichholzer/lg-r290-control.git lg_r290_control
git clone https://github.com/stephan-aichholzer/heatpump_dashboard.git heatpump_dashboard
```

#### 2. Start Systems in Order

**Step 1: Start Shelly BLU Temperature System**
```bash
cd ~/projects/shelly_bt_temp
docker-compose up -d
# This creates the shelly_bt_temp_default network
```

**Step 2: Start Heat Pump Dashboard (creates heatpump_dashboard_default network)**
```bash
cd ~/projects/heatpump_dashboard
docker-compose up -d
# This creates the heatpump_dashboard_default network
```

**Step 3: Start LG R290 Heat Pump Control**
```bash
cd ~/projects/lg_r290_control
docker-compose up -d
# This connects to both external networks
```

#### 3. Verify Integration

**Check Network Connectivity:**
```bash
# Verify Prometheus can reach all targets
docker exec -it heatpump_dashboard_prometheus curl http://modbus_exporter:9100/metrics
docker exec -it heatpump_dashboard_prometheus curl http://iot-api:8000/metrics
docker exec -it heatpump_dashboard_prometheus curl http://lg_r290_service:8000/metrics
```

**Check Prometheus Targets:**
```bash
# Open Prometheus UI
open http://localhost:9090/targets

# Expected targets:
# ✓ wago (modbus_exporter:9100) - UP
# ✓ temperature-sensors (iot-api:8000) - UP
# ✓ heatpump (lg_r290_service:8000) - UP
```

**Verify Metrics Collection:**
```bash
# WAGO energy metrics
curl http://localhost:9090/api/v1/query?query=wago_power_total_kw

# Temperature sensor metrics
curl http://localhost:9090/api/v1/query?query=sensor_temperature_celsius

# Heat pump metrics
curl http://localhost:9090/api/v1/query?query=heatpump_flow_temperature_celsius
```

#### 4. Dashboard Configuration

The Grafana dashboard (`dashboards/heat_pump_dashboard.json`) includes panels for all integrated systems:

**Available Metrics:**
- **Energy Meter**: Power consumption, energy tracking, grid quality
- **Temperature Sensors**: Indoor/outdoor temps, humidity, battery levels, thermostat state
- **Heat Pump**: Flow/return temps, compressor state, operating mode

Import the dashboard into Grafana for unified visualization across all systems.

### Integration Architecture Benefits

**Centralized Monitoring:**
- Single Prometheus instance scrapes all systems
- Unified Grafana dashboard for complete system view
- 1-year data retention for all metrics

**Cross-System Analysis:**
- Correlate power consumption with heat pump operation
- Monitor temperature impact on heating cycles
- Track energy efficiency across the complete system

**Simplified Management:**
- Single backup strategy covers all time-series data
- One monitoring endpoint for all systems
- Consistent metric naming and labeling

### Troubleshooting Multi-System Integration

**Temperature Sensors Not Visible:**
```bash
# Check shelly_bt_temp_default network exists
docker network ls | grep shelly_bt_temp_default

# Verify Prometheus is on the network
docker network inspect shelly_bt_temp_default | grep prometheus

# Check iot-api is reachable
docker exec heatpump_dashboard_prometheus ping -c 1 iot-api
```

**Heat Pump Metrics Missing:**
```bash
# Check heatpump_dashboard_default network
docker network ls | grep heatpump_dashboard_default

# Verify lg_r290_service is on the network
docker network inspect heatpump_dashboard_default | grep lg_r290_service

# Test connectivity
docker exec heatpump_dashboard_prometheus curl http://lg_r290_service:8000/metrics
```

**Restart Order After System Reboot:**
1. Start shelly-blu-ht first (creates network)
2. Start heatpump_dashboard second (creates network)
3. Start lg-r290-control last (connects to both networks)

All containers have `restart: unless-stopped`, so they should auto-start on boot in the correct order.

## Related Documentation

For detailed information about the integrated systems:

- **[LG R290 Control Architecture](https://github.com/stephan-aichholzer/lg-r290-control/blob/main/ARCHITECTURE.md)** - Heat pump control system design
- **[Shelly BLU Architecture](https://github.com/stephan-aichholzer/shelly-blu-ht/blob/main/ARCHITECTURE.md)** - Temperature sensor and thermostat architecture
- **[LG R290 Modbus Reference](https://github.com/stephan-aichholzer/lg-r290-control/blob/main/MODBUS.md)** - Complete LG heat pump register mapping