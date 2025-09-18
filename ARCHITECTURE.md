# WAGO Energy Monitoring Dashboard - Architecture

## Overview

This project implements a comprehensive energy monitoring solution for a 3-phase electrical installation using a WAGO energy meter connected through a Waveshare RS485 Modbus Gateway. The entire monitoring stack runs on a Raspberry Pi host system using Docker containers.

**Current Version: v2.0** - Enhanced with frequency monitoring, power factor tracking, and professional heat pump dashboard with real-time KPIs.

## Physical Architecture

```
┌─────────────────┐    RS485    ┌──────────────────┐    Ethernet    ┌─────────────────────────┐
│   WAGO Energy   │◄───────────►│   Waveshare      │◄──────────────►│    Raspberry Pi         │
│   Meter         │             │   RS485 Modbus   │                │    Host System          │
│   (Slave ID: 2) │             │   Gateway        │                │                         │
└─────────────────┘             │   192.168.2.10   │                │  ┌─────────────────────┐│
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

1. **WAGO Energy Meter**
   - 3-phase electrical energy measurement device
   - Modbus RTU slave (ID: 2)
   - Connected via RS485 interface

2. **Waveshare RS485 Modbus Gateway**
   - Converts RS485 Modbus RTU to TCP/IP
   - IP Address: `192.168.2.10:8899`
   - Enables network access to the WAGO meter

3. **Raspberry Pi Host System**
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

```
WAGO Meter → RS485 → Waveshare Gateway → Network → Raspberry Pi → Modbus Exporter → Prometheus → Grafana
                                        (192.168.2.10:8899)      (Container)    (Container)  (Container)
```

## Component Details

### 1. Modbus Exporter Container (`exporter/exporter.py`)

**Purpose**: Polls the WAGO energy meter via Waveshare gateway and exposes metrics

**Runtime Environment**:
- Docker container on Raspberry Pi
- Python 3.12-slim base image
- Network access to Waveshare gateway

**Key Features**:
- Asynchronous Modbus TCP client
- 30-second polling interval
- Error handling and logging
- Prometheus metrics exposition on port 9100

**Monitored Registers**:
| Metric | Register | Description |
|--------|----------|-------------|
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

**Prometheus Metrics Exposed**:
- `wago_power_total_kw` - Total active power (kW)
- `wago_power_L1_kw`, `wago_power_L2_kw`, `wago_power_L3_kw` - Per-phase power (kW)
- `wago_energy_total_kwh` - Total cumulative energy (kWh)
- `wago_energy_L1_kwh`, `wago_energy_L2_kwh`, `wago_energy_L3_kwh` - Per-phase energy (kWh)
- **`wago_frequency_hz`** ✨ - Grid frequency (Hz)
- **`wago_power_factor`** ✨ - Power factor (Cos φ)

### 2. Prometheus Container

**Purpose**: Time-series database running on Raspberry Pi

**Storage**:
- Data stored in `prometheus_data/` volume on Raspberry Pi filesystem
- 1-year retention policy
- Automatic data compaction

**Configuration**:
- Scrape interval: 30 seconds
- Target: `modbus_exporter:9100` (internal Docker network)
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
- Standard electrical colors (L1=Red, L2=Yellow, L3=Blue)

## Network Configuration

### External Access
- **Grafana Dashboard**: `http://[raspberry-pi-ip]:3000`
- **Prometheus Interface**: `http://[raspberry-pi-ip]:9090`
- **Metrics Endpoint**: `http://[raspberry-pi-ip]:9100/metrics`

### Internal Communication
- **Modbus Gateway**: `192.168.2.10:8899` (external to Raspberry Pi)
- **Container Network**: Docker internal networking between containers

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
```bash
# Backup Prometheus data
docker run --rm -v modbus_prometheus_data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus_backup.tar.gz -C /data .

# Backup Grafana data
docker run --rm -v modbus_grafana_data:/data -v $(pwd):/backup alpine tar czf /backup/grafana_backup.tar.gz -C /data .
```

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