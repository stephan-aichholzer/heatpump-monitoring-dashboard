FROM python:3.12-slim

WORKDIR /app
COPY exporter.py .

RUN pip install pymodbus prometheus_client

CMD ["python", "exporter.py"]

