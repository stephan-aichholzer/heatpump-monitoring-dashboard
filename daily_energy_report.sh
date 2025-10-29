#!/bin/bash

# Get data for last 30 days
START_DATE=$(date -d '30 days ago' '+%Y-%m-%d')
END_DATE=$(date '+%Y-%m-%d')

echo "Attempting to extract daily kWh consumption from Prometheus data..."
echo "Date Range: $START_DATE to $END_DATE"
echo ""
echo "Date       | Start (kWh) | End (kWh)   | Daily (kWh) | Method"
echo "-----------|-------------|-------------|-------------|--------"

# Try to get daily values using @ modifier (snap to start/end of day)
for i in {0..30}; do
    DATE=$(date -d "$i days ago" '+%Y-%m-%d')
    MIDNIGHT_START=$(date -d "$DATE 00:00:00" +%s)
    MIDNIGHT_END=$(date -d "$DATE 23:59:59" +%s)
    
    # Query value at start of day
    START_VAL=$(curl -s "http://localhost:9090/api/v1/query?query=wago_energy_total_kwh&time=${MIDNIGHT_START}" | jq -r '.data.result[0].value[1] // "N/A"')
    
    # Query value at end of day
    END_VAL=$(curl -s "http://localhost:9090/api/v1/query?query=wago_energy_total_kwh&time=${MIDNIGHT_END}" | jq -r '.data.result[0].value[1] // "N/A"')
    
    # Calculate daily consumption
    if [[ "$START_VAL" != "N/A" && "$END_VAL" != "N/A" ]]; then
        DAILY=$(echo "$END_VAL - $START_VAL" | bc -l)
        printf "%s | %11.3f | %11.3f | %11.3f | snap\n" "$DATE" "$START_VAL" "$END_VAL" "$DAILY"
    else
        printf "%s | %11s | %11s | %11s | no data\n" "$DATE" "$START_VAL" "$END_VAL" "N/A"
    fi
done
