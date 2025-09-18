# WAGO Energy Monitoring Dashboard - Architecture

## Overview

This project implements a comprehensive energy monitoring solution for a 3-phase electrical installation using a WAGO energy meter connected through a Waveshare RS485 Modbus Gateway. The entire monitoring stack runs on a Raspberry Pi host system using Docker containers.

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
| Total Energy | `0x6000` | Total active energy (kWh) |
| L1 Energy | `0x6006` | L1 phase active energy (kWh) |
| L2 Energy | `0x6008` | L2 phase active energy (kWh) |
| L3 Energy | `0x600A` | L3 phase active energy (kWh) |

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
- Real-time power consumption visualization
- Historical energy usage trends
- Per-phase electrical analysis

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