FROM python:3.12-slim

WORKDIR /app
COPY exporter.py .

RUN pip install pymodbus==3.6.9 prometheus_client

CMD ["python", "exporter.py"]

