# Heat Pump Monitoring Dashboard

A comprehensive monitoring solution for heating systems with integrated energy metering, temperature sensing, and heat pump control. Central hub for your complete heating ecosystem with professional-grade insights.

**Perfect for small to medium heat pumps (up to 7kW) • 1-year data retention • 30-second granularity**

## 🎯 What It Monitors

- **⚡ Energy Consumption** - 3-phase power via Modbus meters (WAGO, Shelly Pro 3EM, or compatible)
- **🔥 Heat Pump** - Real-time operation via [LG R290 Control](https://github.com/stephan-aichholzer/lg-r290-control)
- **🌡️ Temperature** - Multi-zone monitoring via [Shelly BLU Sensors](https://github.com/stephan-aichholzer/shelly-blu-ht)
- **📊 Grid Quality** - Frequency stability and power factor

## 🚀 Key Features

- **Unified Dashboard** - Grafana interface with all metrics in one place
- **Multi-System Integration** - Energy meter + heat pump + temperature sensors
- **Data Quality** - Spike filtering, monotonic counters, auto-reconnect
- **Heat Pump Optimized** - Thresholds tuned for 6W standby / 46W active operation
- **Long-term Analysis** - 1-year Prometheus retention for seasonal patterns
- **Extensible** - Modular design, works standalone or fully integrated

**Tech Stack**: Docker Compose • Prometheus • Grafana • Python Modbus

## 📋 Quick Start

### Prerequisites

**Required:**
- 3-phase Modbus energy meter (WAGO tested, others adaptable)
- Modbus gateway (if RS485) or direct TCP connection
- Docker-capable host (Raspberry Pi recommended)

**Optional Integrations:**
- [LG R290 Heat Pump Control](https://github.com/stephan-aichholzer/lg-r290-control) - Heat pump monitoring & control
- [Shelly BLU Temperature](https://github.com/stephan-aichholzer/shelly-blu-ht) - Multi-zone temperature & thermostat

### Installation

```bash
# 1. Clone repository
git clone https://github.com/stephan-aichholzer/heatpump-monitoring-dashboard.git
cd heatpump-monitoring-dashboard

# 2. Configure your energy meter (edit exporter/exporter.py)
# Set MODBUS_IP, MODBUS_PORT, SLAVE_ID to match your meter

# 3. Start services
docker-compose up -d

# 4. Verify operation
curl http://localhost:9100/metrics | grep wago_power  # Energy meter
curl http://localhost:9090/targets                     # Prometheus targets
```

### Access Dashboards

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- Import dashboard: `dashboards/heat_pump_dashboard.json`

## 🔌 Energy Meter Compatibility

**Tested**: WAGO (default) | **Adaptable**: Shelly Pro 3EM, any Modbus meter

To adapt for your meter:

1. Find your meter's Modbus register map (manual/datasheet)
2. Update register addresses in `exporter/exporter.py` (lines 128-140)
3. Update connection in `exporter/exporter.py` (lines 45-47)

**WAGO Register Reference** (example - adjust for your meter):

| Metric | Register | Type |
|--------|----------|------|
| Total Power | 0x5012 | Float32 |
| L1/L2/L3 Power | 0x5014/16/18 | Float32 |
| Total Energy | 0x6000 | Float32 |
| L1/L2/L3 Energy | 0x6006/08/0A | Float32 |
| Frequency | 0x5008 | Float32 |
| Power Factor | 0x502A | Float32 |

**Community contributions welcome!** Share your meter configurations via pull request.

## 📈 Metrics Overview

### Energy Metering
- Power: `wago_power_total_kw`, `wago_power_L1/L2/L3_kw`
- Energy: `wago_energy_total_kwh`, `wago_energy_L1/L2/L3_kwh`
- Grid: `wago_frequency_hz`, `wago_power_factor`

### Heat Pump (via [lg-r290-control](https://github.com/stephan-aichholzer/lg-r290-control))
- Temperatures: `heatpump_flow/return/outdoor_temperature_celsius`
- Status: `heatpump_power_state`, `heatpump_compressor_running`
- Mode: `heatpump_operating_mode` (0=Standby, 1=Cooling, 2=Heating, 3=Auto)

### Temperature (via [shelly-blu-ht](https://github.com/stephan-aichholzer/shelly-blu-ht))
- Climate: `sensor_temperature_celsius`, `sensor_humidity_percent`
- Thermostat: `thermostat_switch_state`, `thermostat_target_temperature_celsius`

*Full metrics reference: See [ARCHITECTURE.md](ARCHITECTURE.md)*

## 🔧 Multi-System Integration

For complete heating ecosystem monitoring, integrate with external services:

**1. [Shelly BLU Temperature Sensors](https://github.com/stephan-aichholzer/shelly-blu-ht)**
```bash
cd ~/projects
git clone https://github.com/stephan-aichholzer/shelly-blu-ht.git
cd shelly-blu-ht
docker-compose up -d  # Creates shelly_bt_temp_default network
```

**2. [LG R290 Heat Pump Control](https://github.com/stephan-aichholzer/lg-r290-control)**
```bash
cd ~/projects
git clone https://github.com/stephan-aichholzer/lg-r290-control.git
cd lg-r290-control
docker-compose up -d  # Connects to heatpump_dashboard_default network
```

**3. Verify Integration**
```bash
# Check Prometheus is scraping all targets
curl http://localhost:9090/api/v1/targets
# Should show: wago, temperature-sensors, heatpump (all UP)
```

*Detailed integration guide: See [ARCHITECTURE.md](ARCHITECTURE.md#multi-system-integration-guide)*

## 🛠 Troubleshooting

**No data in dashboard**
- Check services: `docker-compose ps`
- View logs: `docker-compose logs modbus_exporter`
- Test metrics: `curl http://localhost:9100/metrics`

**Connection timeouts**
- Verify Modbus IP/port in `exporter/exporter.py`
- Test gateway: `ping <gateway-ip>` and `telnet <gateway-ip> <port>`

**Wrong/missing values**
- Check Modbus slave ID matches your meter
- Verify register addresses match your meter's manual
- Check logs: `docker-compose logs modbus_exporter`

**Integration issues**
- Ensure external networks exist: `docker network ls | grep -E "shelly_bt_temp|heatpump_dashboard"`
- Start order: shelly-blu-ht → heatpump-dashboard → lg-r290-control

*Advanced troubleshooting: See [ARCHITECTURE.md](ARCHITECTURE.md#troubleshooting)*

## 📦 Backup & Maintenance

**Quick Backup**
```bash
./backup.sh
# Creates: backup_YYYYMMDD_HHMMSS.tar.gz
# Contains: Git repo, Docker volumes, Grafana dashboards
```

**Update Services**
```bash
docker-compose pull
docker-compose up -d
```

## 📚 Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design, component details, network configuration
- **[Related Projects](ARCHITECTURE.md#integrated-system-components)** - Full ecosystem overview

## 🔗 Related Projects

This project serves as the central monitoring hub. For complete heating system control:

- **[lg-r290-control](https://github.com/stephan-aichholzer/lg-r290-control)** - LG R290 heat pump Modbus control with web UI
- **[shelly-blu-ht](https://github.com/stephan-aichholzer/shelly-blu-ht)** - Shelly BLU sensors with intelligent thermostat

```
┌─────────────────────────────────────────────┐
│      Complete Heating Ecosystem             │
├─────────────────────────────────────────────┤
│                                             │
│  Shelly BLU Sensors ────┐                  │
│  LG R290 Heat Pump ─────┼─────► Central    │
│  Energy Meter ──────────┘       Dashboard  │
│                          (this project)     │
└─────────────────────────────────────────────┘
```

## 🤝 Contributing

Contributions welcome! Especially:
- Energy meter adapter configurations (Shelly Pro 3EM, others)
- Dashboard improvements
- Documentation enhancements

## 📄 License

MIT License - see [LICENSE](LICENSE) file

**Third-party**: pymodbus (BSD-3), Prometheus (Apache-2.0), Grafana (AGPL-3.0)
Details: [NOTICE](NOTICE)

---

**Professional-grade heating system monitoring** • Central hub for energy, temperature, and heat pump metrics
