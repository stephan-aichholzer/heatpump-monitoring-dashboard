import asyncio
import logging
import warnings
from pymodbus.client import AsyncModbusTcpClient
from pymodbus.constants import Endian
from pymodbus.payload import BinaryPayloadDecoder

class SuppressBinaryPayloadDecoderWarning(logging.Filter):
    def filter(self, record):
        return "BinaryPayloadDecoder is deprecated" not in record.getMessage()

logging.basicConfig()
logging.getLogger().setLevel(logging.INFO)

# Apply this filter to pymodbus.logging logger
logging.getLogger("pymodbus.logging").addFilter(SuppressBinaryPayloadDecoderWarning())


MODBUS_IP = "192.168.2.10"
MODBUS_PORT = 8899
SLAVE_ID = 2

REGISTERS = {
    'Total Energy': 0x6000,
    'L1 Energy': 0x6006,
    'L2 Energy': 0x6008,
    'L3 Energy': 0x600A,
    'Total Power': 0x5012,
    'L1 Power': 0x5014,
    'L2 Power': 0x5016,
    'L3 Power': 0x5018
}

def hex_dump(registers):
    return ' '.join(f'{reg:04X}' for reg in registers)

async def read_and_dump(client, label, address, slave_id):
    print(f"\nRequesting {label} at 0x{address:04X} (dec {address})...")
    result = await client.read_holding_registers(address=address, count=2, slave=slave_id)

    if result.isError():
        print(f"❌ Error reading register {hex(address)}: {result}")
        return

    logging.debug(f"Raw registers: {result.registers}")
    logging.debug(f"Hex dump     : {hex_dump(result.registers)}")

    # Use BinaryPayloadDecoder for now (stable and supports endian config)
    decoder = BinaryPayloadDecoder.fromRegisters(
        result.registers,
        byteorder=Endian.BIG,
        wordorder=Endian.BIG
    )
    value = decoder.decode_32bit_float()
    print(f"{label} value : {value:.2f} kWh")

async def main():
    async with AsyncModbusTcpClient(MODBUS_IP, port=MODBUS_PORT) as client:
        for label, addr in REGISTERS.items():
            await read_and_dump(client, label, addr, SLAVE_ID)

if __name__ == "__main__":
    asyncio.run(main())

