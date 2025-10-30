#!/bin/bash

# Daily Energy Report - Extract daily kWh consumption from Prometheus
# Usage: ./daily_energy_report.sh [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--format csv|table]

# Default values
START_DATE=$(date -d '30 days ago' '+%Y-%m-%d')
END_DATE=$(date -d 'yesterday' '+%Y-%m-%d')  # Exclude today (incomplete data)
FORMAT="table"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --from)
            START_DATE="$2"
            shift 2
            ;;
        --to)
            END_DATE="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--format csv|table]"
            echo ""
            echo "Options:"
            echo "  --from DATE    Start date in ISO8601 format (default: 30 days ago)"
            echo "  --to DATE      End date in ISO8601 format (default: today)"
            echo "  --format FMT   Output format: csv or table (default: table)"
            echo ""
            echo "Examples:"
            echo "  $0 --from 2025-10-01 --to 2025-10-31 --format csv"
            echo "  $0 --from 2025-09-01 --to 2025-09-30 --format csv > september.csv"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate date format
if ! date -d "$START_DATE" >/dev/null 2>&1; then
    echo "Error: Invalid start date format: $START_DATE"
    echo "Use ISO8601 format: YYYY-MM-DD"
    exit 1
fi

if ! date -d "$END_DATE" >/dev/null 2>&1; then
    echo "Error: Invalid end date format: $END_DATE"
    echo "Use ISO8601 format: YYYY-MM-DD"
    exit 1
fi

# Calculate number of days
START_TS=$(date -d "$START_DATE" +%s)
END_TS=$(date -d "$END_DATE" +%s)
DAYS=$(( (END_TS - START_TS) / 86400 ))

if [ $DAYS -lt 0 ]; then
    echo "Error: Start date must be before end date"
    exit 1
fi

# Output header
if [ "$FORMAT" = "csv" ]; then
    echo "Date,Start_kWh,End_kWh,Daily_kWh,Status"
else
    echo "Extracting daily kWh consumption from Prometheus data..."
    echo "Date Range: $START_DATE to $END_DATE ($((DAYS + 1)) days)"
    echo ""
    echo "Date       | Start (kWh) | End (kWh)   | Daily (kWh) | Status"
    echo "-----------|-------------|-------------|-------------|--------"
fi

# Extract daily values
for i in $(seq 0 $DAYS); do
    DATE=$(date -d "$START_DATE + $i days" '+%Y-%m-%d')
    MIDNIGHT_START=$(date -d "$DATE 00:00:00" +%s)
    MIDNIGHT_END=$(date -d "$DATE 23:59:59" +%s)

    # Query value at start of day
    START_VAL=$(curl -s "http://localhost:9090/api/v1/query?query=wago_energy_total_kwh&time=${MIDNIGHT_START}" | jq -r '.data.result[0].value[1] // "N/A"')

    # Query value at end of day
    END_VAL=$(curl -s "http://localhost:9090/api/v1/query?query=wago_energy_total_kwh&time=${MIDNIGHT_END}" | jq -r '.data.result[0].value[1] // "N/A"')

    # Calculate daily consumption
    if [[ "$START_VAL" != "N/A" && "$END_VAL" != "N/A" ]]; then
        DAILY=$(echo "$END_VAL - $START_VAL" | bc -l)
        if [ "$FORMAT" = "csv" ]; then
            printf "%s,%.1f,%.1f,%.1f,OK\n" "$DATE" "$START_VAL" "$END_VAL" "$DAILY"
        else
            printf "%s | %11.1f | %11.1f | %11.1f | OK\n" "$DATE" "$START_VAL" "$END_VAL" "$DAILY"
        fi
    else
        if [ "$FORMAT" = "csv" ]; then
            printf "%s,%s,%s,%s,NO_DATA\n" "$DATE" "$START_VAL" "$END_VAL" "N/A"
        else
            printf "%s | %11s | %11s | %11s | no data\n" "$DATE" "$START_VAL" "$END_VAL" "N/A"
        fi
    fi
done
