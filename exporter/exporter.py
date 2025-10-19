import asyncio
import logging
from prometheus_client import start_http_server, Gauge
from pymodbus.client import AsyncModbusTcpClient
from pymodbus.constants import Endian
from pymodbus.payload import BinaryPayloadDecoder

# Prometheus metrics

power_kw = Gauge("wago_power_total_kw", "Total active power (kW)")
energy_kwh = Gauge("wago_energy_total_kwh", "Total active energy (kWh)")

energy_l1_kwh = Gauge("wago_energy_L1_kwh", "L1 active energy (kWh)")
energy_l2_kwh = Gauge("wago_energy_L2_kwh", "L2 active energy (kWh)")
energy_l3_kwh = Gauge("wago_energy_L3_kwh", "L3 active energy (kWh)")

power_l1_kw = Gauge("wago_power_L1_kw", "L1 active power (kW)")
power_l2_kw = Gauge("wago_power_L2_kw", "L2 active power (kW)")
power_l3_kw = Gauge("wago_power_L3_kw", "L3 active power (kW)")

frequency_hz = Gauge("wago_frequency_hz", "Grid frequency (Hz)")
power_factor = Gauge("wago_power_factor", "Power factor (Cos φ)")

# Track last valid energy values to ensure monotonic increasing
last_energy = {"total": 0.0, "l1": 0.0, "l2": 0.0, "l3": 0.0}

# Track last valid power values for spike filtering
last_power = {"total": 0.0, "l1": 0.0, "l2": 0.0, "l3": 0.0}

# Track recent power values to detect anomalous single-spike garbage values
# Format: {"metric_name": [value1, value2, value3]} - keeps last 3 readings
power_history = {
    "total": [],
    "l1": [],
    "l2": [],
    "l3": []
}

# Configuration for spike/garbage detection
MIN_VALID_POWER_KW = 0.001  # 1W - values below this are likely bus errors (e.g., 3.67e-27)
CONSECUTIVE_LOW_REQUIRED = 2  # Number of consecutive low readings needed to accept as real
POWER_HISTORY_SIZE = 3  # Number of samples to keep for spike detection

# Modbus config
MODBUS_IP = "192.168.2.10"
MODBUS_PORT = 8899
SLAVE_ID = 2
POLL_INTERVAL_SECONDS = 30

async def read_float32(client, address):
    try:
        result = await client.read_holding_registers(address=address, count=2, slave=SLAVE_ID)
        if result.isError():
            logging.warning(f"Modbus error at 0x{address:04X}")
            return None
        decoder = BinaryPayloadDecoder.fromRegisters(result.registers, byteorder=Endian.BIG, wordorder=Endian.BIG)
        return decoder.decode_32bit_float()
    except Exception as e:
        logging.error(f"Exception reading 0x{address:04X}: {e}")
        return None

def validate_power_value(value, metric_name, last_valid_value=None):
    """
    Validates power readings to filter out bus interference garbage values.

    Strategy:
    - Values < 1W (0.001 kW) are suspicious (could be garbage like 3.67e-27 or bus errors)
    - Single suspicious values are ignored (spike filtering)
    - Only accept low values if they appear consecutively (real power drop to zero)

    Args:
        value: The new power reading in kW
        metric_name: Which power metric (total, l1, l2, l3)
        last_valid_value: The last accepted valid value (for fallback)

    Returns:
        tuple: (validated_value, should_update)
    """
    if value is None:
        return (last_valid_value, False)

    # Add to history
    history = power_history[metric_name]
    history.append(value)
    if len(history) > POWER_HISTORY_SIZE:
        history.pop(0)

    # Check if current value is suspiciously low (< 1W)
    is_low = abs(value) < MIN_VALID_POWER_KW

    if not is_low:
        # Value is above threshold - it's valid, accept it
        return (value, True)

    # Value is low - check if it's a single spike or consistent
    if len(history) < CONSECUTIVE_LOW_REQUIRED:
        # Not enough history yet, be conservative - reject low value
        logging.warning(f"{metric_name} power suspiciously low ({value:.2e} kW) - insufficient history, keeping last value")
        return (last_valid_value, False)

    # Count consecutive low values in recent history
    consecutive_low = sum(1 for v in history[-CONSECUTIVE_LOW_REQUIRED:] if abs(v) < MIN_VALID_POWER_KW)

    if consecutive_low >= CONSECUTIVE_LOW_REQUIRED:
        # Multiple consecutive low readings - this is likely real (e.g., system idle)
        logging.info(f"{metric_name} power legitimately low: {value:.6f} kW (confirmed by {consecutive_low} consecutive readings)")
        return (value, True)
    else:
        # Single low spike - likely bus interference, reject it
        logging.warning(f"{metric_name} power garbage value detected ({value:.2e} kW) - single spike, keeping last value {last_valid_value:.3f} kW")
        return (last_valid_value, False)

async def poll_loop():
    """Main polling loop with connection resilience"""
    while True:
        try:
            async with AsyncModbusTcpClient(MODBUS_IP, port=MODBUS_PORT) as client:
                logging.info(f"Connected to Modbus gateway at {MODBUS_IP}:{MODBUS_PORT}")
                await poll_iteration(client)
        except Exception as e:
            logging.error(f"Connection lost or error in poll loop: {e}")
            logging.info(f"Reconnecting in {POLL_INTERVAL_SECONDS} seconds...")
            await asyncio.sleep(POLL_INTERVAL_SECONDS)

async def poll_iteration(client):
    """Single polling iteration - separated for better error handling"""
    while True:
        power = await read_float32(client, 0x5012)
        energy = await read_float32(client, 0x6000)

        energy_l1 = await read_float32(client, 0x6006)
        energy_l2 = await read_float32(client, 0x6008)
        energy_l3 = await read_float32(client, 0x600A)

        power_l1 = await read_float32(client, 0x5014)
        power_l2 = await read_float32(client, 0x5016)
        power_l3 = await read_float32(client, 0x5018)

        frequency = await read_float32(client, 0x5008)
        pf = await read_float32(client, 0x502A)

        # Power metrics - filter out garbage/spike values below 1W
        # Use smart validation to ignore single anomalous low readings but accept consecutive low values
        validated_power, should_update = validate_power_value(power, "total", last_power["total"])
        if should_update:
            power_kw.set(validated_power)
            last_power["total"] = validated_power

        validated_power_l1, should_update_l1 = validate_power_value(power_l1, "l1", last_power["l1"])
        if should_update_l1:
            power_l1_kw.set(validated_power_l1)
            last_power["l1"] = validated_power_l1

        validated_power_l2, should_update_l2 = validate_power_value(power_l2, "l2", last_power["l2"])
        if should_update_l2:
            power_l2_kw.set(validated_power_l2)
            last_power["l2"] = validated_power_l2

        validated_power_l3, should_update_l3 = validate_power_value(power_l3, "l3", last_power["l3"])
        if should_update_l3:
            power_l3_kw.set(validated_power_l3)
            last_power["l3"] = validated_power_l3

        # Energy metrics - MUST be monotonically increasing (never decrease or reset to zero)
        if energy is not None and energy > 0:
            if energy >= last_energy["total"]:
                energy_kwh.set(energy)
                last_energy["total"] = energy
            else:
                logging.warning(f"Energy decreased from {last_energy['total']:.2f} to {energy:.2f} kWh - keeping last value")
        elif energy is not None:
            logging.warning(f"Energy counter returned zero or invalid value: {energy} - keeping last value {last_energy['total']:.2f} kWh")

        if energy_l1 is not None and energy_l1 > 0:
            if energy_l1 >= last_energy["l1"]:
                energy_l1_kwh.set(energy_l1)
                last_energy["l1"] = energy_l1
            else:
                logging.warning(f"L1 energy decreased from {last_energy['l1']:.2f} to {energy_l1:.2f} kWh - keeping last value")
        elif energy_l1 is not None:
            logging.warning(f"L1 energy counter returned zero or invalid value: {energy_l1} - keeping last value {last_energy['l1']:.2f} kWh")

        if energy_l2 is not None and energy_l2 > 0:
            if energy_l2 >= last_energy["l2"]:
                energy_l2_kwh.set(energy_l2)
                last_energy["l2"] = energy_l2
            else:
                logging.warning(f"L2 energy decreased from {last_energy['l2']:.2f} to {energy_l2:.2f} kWh - keeping last value")
        elif energy_l2 is not None:
            logging.warning(f"L2 energy counter returned zero or invalid value: {energy_l2} - keeping last value {last_energy['l2']:.2f} kWh")

        if energy_l3 is not None and energy_l3 > 0:
            if energy_l3 >= last_energy["l3"]:
                energy_l3_kwh.set(energy_l3)
                last_energy["l3"] = energy_l3
            else:
                logging.warning(f"L3 energy decreased from {last_energy['l3']:.2f} to {energy_l3:.2f} kWh - keeping last value")
        elif energy_l3 is not None:
            logging.warning(f"L3 energy counter returned zero or invalid value: {energy_l3} - keeping last value {last_energy['l3']:.2f} kWh")

        # Grid quality metrics - can be any value
        if frequency is not None:
            frequency_hz.set(frequency)

        if pf is not None:
            power_factor.set(pf)

        await asyncio.sleep(POLL_INTERVAL_SECONDS)

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    start_http_server(9100)  # Prometheus endpoint
    print("Exporter running on http://localhost:9100/metrics")

    asyncio.run(poll_loop())

