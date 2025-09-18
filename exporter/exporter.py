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

async def poll_loop():
    async with AsyncModbusTcpClient(MODBUS_IP, port=MODBUS_PORT) as client:
        while True:
            power = await read_float32(client, 0x5012)
            energy = await read_float32(client, 0x6000)

            energy_l1 = await read_float32(client, 0x6006)
            energy_l2 = await read_float32(client, 0x6008)
            energy_l3 = await read_float32(client, 0x600A)

            power_l1 = await read_float32(client, 0x5014)
            power_l2 = await read_float32(client, 0x5016)
            power_l3 = await read_float32(client, 0x5018)
            
            if power is not None:
                power_kw.set(power)

            if power_l1 is not None:
                power_l1_kw.set(power_l1)

            if power_l2 is not None:
                power_l2_kw.set(power_l2)
            
            if power_l3 is not None:
                power_l3_kw.set(power_l3)

            if energy is not None:
                energy_kwh.set(energy)

            if energy_l1 is not None:
                energy_l1_kwh.set(energy_l1)

            if energy_l2 is not None:
                energy_l2_kwh.set(energy_l2)

            if energy_l3 is not None:
                energy_l3_kwh.set(energy_l3)

            await asyncio.sleep(POLL_INTERVAL_SECONDS)

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    start_http_server(9100)  # Prometheus endpoint
    print("Exporter running on http://localhost:9100/metrics")

    asyncio.run(poll_loop())

