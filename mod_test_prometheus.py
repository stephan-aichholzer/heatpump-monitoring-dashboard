import asyncio
import logging
from prometheus_client import start_http_server, Gauge
from pymodbus.client import AsyncModbusTcpClient
from pymodbus.constants import Endian
from pymodbus.payload import BinaryPayloadDecoder

# Prometheus metrics
power_kw = Gauge("wago_power_total_kw", "Total active power (kW)")
energy_kwh = Gauge("wago_energy_total_kwh", "Total active energy (kWh)")

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

            if power is not None:
                power_kw.set(power)
            if energy is not None:
                energy_kwh.set(energy)

            await asyncio.sleep(POLL_INTERVAL_SECONDS)

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    start_http_server(9100)  # Prometheus endpoint
    print("Exporter running on http://localhost:9100/metrics")

    asyncio.run(poll_loop())

