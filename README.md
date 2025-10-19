# WAGO Energy Monitoring Dashboard

A comprehensive energy monitoring solution for heat pump systems using WAGO energy meters connected through Waveshare RS485 Modbus Gateway. Provides real-time power consumption tracking, grid quality monitoring, and historical energy data visualization.

## 🚀 Features

### Core Monitoring
- **Real-time Power Consumption** - Monitor total and per-phase power (6W standby / 46W active)
- **Energy Tracking** - Cumulative and daily energy consumption per phase
- **Grid Quality** - Frequency stability and power factor monitoring
- **Heat Pump Optimization** - Small heat pump optimized thresholds (0-1-2kW)
- **Data Quality** ✨ *New in v2.2* - Power spike filtering and monotonic energy counter protection
- **External Sensors** - Integrated IoT temperature sensors and heat pump metrics via Docker networking

### Professional Dashboard
- **Live KPIs** - Current power, frequency, power factor, daily energy
- **Time Series Graphs** - Power trends, energy consumption, phase balance
- **Color-coded Alerts** - Visual indicators for system status
- **Standard Electrical Colors** - L1=Red, L2=Yellow, L3=Blue

### Technical Specifications
- **Polling Interval**: 30 seconds
- **Data Retention**: 1 year (Prometheus)
- **Metrics Format**: Prometheus-compatible
- **Dashboard Refresh**: 30 seconds
- **Container Architecture**: Docker Compose

## 📋 Prerequisites

### Hardware Requirements
- **WAGO Energy Meter** (3-phase, Modbus RTU slave)
- **Waveshare RS485 Modbus Gateway** (or compatible TCP/IP converter)
- **Host System** (Raspberry Pi recommended)

### Software Requirements
- Docker and Docker Compose
- Network connectivity to Modbus gateway
- Available ports: 3000 (Grafana), 9090 (Prometheus), 9100 (Exporter)

### Network Configuration
- **Modbus Gateway**: Must be accessible at `192.168.2.10:8899`
- **Slave ID**: WAGO device configured as slave ID `2`
- **External Sensors** (Optional): IoT temperature API and heat pump service via Docker network
  - Requires external Docker network: `shelly_bt_temp_default`
  - Temperature sensors: `iot-api:8000`
  - Heat pump metrics: `lg_r290_service:8000`

## 🔧 Installation

### 1. Clone Repository
```bash
git clone https://github.com/stephan-aichholzer/wago-energy-modbus-dashboard.git
cd wago-energy-modbus-dashboard
```

### 2. Configure Network (if needed)
Edit `exporter/exporter.py` if your Modbus gateway uses different settings:
```python
MODBUS_IP = "192.168.2.10"    # Your gateway IP
MODBUS_PORT = 8899            # Your gateway port
SLAVE_ID = 2                  # Your WAGO slave ID
```

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

## 📈 Monitoring Metrics

### Power Metrics
| Metric | Description | Unit | Example |
|--------|-------------|------|---------|
| `wago_power_total_kw` | Total active power | kW | 0.046 (46W) |
| `wago_power_L1_kw` | L1 phase power | kW | 0.046 |
| `wago_power_L2_kw` | L2 phase power | kW | 0.000 |
| `wago_power_L3_kw` | L3 phase power | kW | 0.000 |

### Energy Metrics
| Metric | Description | Unit | Example |
|--------|-------------|------|---------|
| `wago_energy_total_kwh` | Total cumulative energy | kWh | 87.33 |
| `wago_energy_L1_kwh` | L1 cumulative energy | kWh | 39.98 |
| `wago_energy_L2_kwh` | L2 cumulative energy | kWh | 24.64 |
| `wago_energy_L3_kwh` | L3 cumulative energy | kWh | 21.57 |

### Grid Quality Metrics ✨ *New in v2.0*
| Metric | Description | Unit | Example |
|--------|-------------|------|---------|
| `wago_frequency_hz` | Grid frequency | Hz | 49.98 |
| `wago_power_factor` | Power factor (Cos φ) | ratio | 0.240 |

### Temperature Sensor Metrics ✨ *New in v2.1*
| Metric | Description | Unit | Example |
|--------|-------------|------|---------|
| `sensor_temperature_celsius` | Temperature readings | °C | 22.5 |
| `sensor_humidity_percent` | Humidity readings | % | 45.2 |
| `sensor_battery_percent` | Battery level | % | 85 |
| `sensor_last_seen_timestamp` | Last sensor update | timestamp | 1759050278 |

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
docker-compose restart modbus_exporter

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

### Temperature Sensor Issues ✨ *New in v2.1*
```bash
# Check temperature sensor API is responding
curl http://192.168.2.11:8001/api/v1/sensors

# Verify latest temperature readings
curl http://192.168.2.11:8001/api/v1/temperature?limit=3

# Check metrics endpoint synchronization
curl http://192.168.2.11:8001/metrics | grep sensor_temperature

# Verify Prometheus is scraping temperature sensors
curl http://localhost:9090/api/v1/query?query=sensor_temperature_celsius
```

### Common Issues
1. **No data in dashboard**: Check Prometheus is scraping metrics
2. **Connection timeouts**: Verify Modbus gateway IP and port
3. **Missing frequency/power factor**: Ensure WAGO supports registers 0x5008/0x502A
4. **Wrong values**: Check WAGO slave ID configuration
5. **Temperature data stuck**: Check metrics endpoint reflects latest API values
6. **Container unhealthy**: Restart temperature sensor container with `docker restart iot-api`
7. **Power spikes/garbage values**: v2.2+ includes automatic spike filtering (requires 2 consecutive low readings)
8. **Energy counter resets**: v2.2+ includes monotonic counter protection to prevent backward jumps

## 📁 Project Structure

```
.
├── docker-compose.yml              # Service orchestration
├── exporter/                       # Modbus data collector
│   ├── Dockerfile                  # Container definition
│   └── exporter.py                 # Main collection script (with spike filtering)
├── prometheus/                     # Time series database
│   ├── prometheus.yml              # Scraping configuration
│   └── wago_recording_rules.yml    # Recording rules for aggregation
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
docker run --rm -v modbus_prometheus_data:/data \
  -v $(pwd):/backup alpine tar czf /backup/prometheus_backup.tar.gz -C /data .

# Backup Grafana data only
docker run --rm -v modbus_grafana_data:/data \
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
- ✅ Prometheus recording rules for daily/monthly aggregation
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

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is open source. Feel free to use, modify, and distribute.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review container logs: `docker-compose logs`
3. Open an issue on GitHub with system details and logs

---

**Perfect for small heat pump monitoring with professional-grade insights! 🎯**