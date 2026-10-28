#!/bin/bash

# Daily Energy Report - Extract daily kWh consumption from Prometheus
# Usage: ./daily_energy_report.sh [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--format csv|table]

# Default values
START_DATE=$(date -d '30 days ago' '+%Y-%m-%d')
END_DATE=$(date -d 'yesterday' '+%Y-%m-%d')  # Exclude today (incomplete data)
FORMAT="table"
INCLUDE_DEFROST=false

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
        --include-defrost)
            INCLUDE_DEFROST=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--format csv|table] [--include-defrost]"
            echo ""
            echo "Options:"
            echo "  --from DATE       Start date in ISO8601 format (default: 30 days ago)"
            echo "  --to DATE         End date in ISO8601 format (default: today)"
            echo "  --format FMT      Output format: csv or table (default: table)"
            echo "  --include-defrost Include defrost cycle count (slower, queries raw power data)"
            echo ""
            echo "Examples:"
            echo "  $0 --from 2025-10-01 --to 2025-10-31 --format csv"
            echo "  $0 --from 2025-12-01 --to 2025-12-24 --include-defrost"
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
# Count days in UTC. Parsing these as local time makes the span a non-multiple
# of 86400 whenever a DST change falls between the two dates (the spring switch
# shortens it by an hour), and the integer division then drops the final day.
# The per-day loop below still uses local-time date arithmetic, which is correct.
START_TS=$(date -u -d "$START_DATE 00:00:00 UTC" +%s)
END_TS=$(date -u -d "$END_DATE 00:00:00 UTC" +%s)
DAYS=$(( (END_TS - START_TS) / 86400 ))

if [ $DAYS -lt 0 ]; then
    echo "Error: Start date must be before end date"
    exit 1
fi

# Output header
if [ "$FORMAT" = "csv" ]; then
    if [ "$INCLUDE_DEFROST" = true ]; then
        echo "Date,Start_kWh,End_kWh,Daily_kWh,Avg_Outdoor_C,Avg_Flow_C,Stove,Defrost,Status"
    else
        echo "Date,Start_kWh,End_kWh,Daily_kWh,Avg_Outdoor_C,Avg_Flow_C,Stove,Status"
    fi
else
    echo "Extracting daily kWh consumption and outdoor temperature from Prometheus data..."
    echo "Date Range: $START_DATE to $END_DATE ($((DAYS + 1)) days)"
    echo ""
    if [ "$INCLUDE_DEFROST" = true ]; then
        echo "Date       | Start (kWh) | End (kWh)   | Daily (kWh) | Out °C | Flow °C | Stove | Defr | Status"
        echo "-----------|-------------|-------------|-------------|--------|---------|-------|------|--------"
    else
        echo "Date       | Start (kWh) | End (kWh)   | Daily (kWh) | Out °C | Flow °C | Stove | Status"
        echo "-----------|-------------|-------------|-------------|--------|---------|-------|--------"
    fi
fi

# Initialize summary variables for table format
TOTAL_KWH=0
TOTAL_TEMP=0
VALID_DAYS=0
VALID_TEMP_DAYS=0

# Extract daily values
for i in $(seq 0 $DAYS); do
    DATE=$(date -d "$START_DATE + $i days" '+%Y-%m-%d')
    MIDNIGHT_START=$(date -d "$DATE 00:00:00" +%s)
    MIDNIGHT_END=$(date -d "$DATE 23:59:59" +%s)

    # Query value at start of day
    START_VAL=$(curl -s "http://localhost:9090/api/v1/query?query=wago_energy_total_kwh&time=${MIDNIGHT_START}" | jq -r '.data.result[0].value[1] // "N/A"')

    # Query value at end of day
    END_VAL=$(curl -s "http://localhost:9090/api/v1/query?query=wago_energy_total_kwh&time=${MIDNIGHT_END}" | jq -r '.data.result[0].value[1] // "N/A"')

    # Query average outdoor temperature for the day
    # URL encode properly: = becomes %3D, " becomes %22, { becomes %7B, } becomes %7D, [ becomes %5B, ] becomes %5D
    AVG_TEMP=$(curl -s "http://localhost:9090/api/v1/query?query=avg_over_time(sensor_temperature_celsius%7Bsensor_name%3D%22temp_outdoor%22%7D%5B1d%5D)&time=${MIDNIGHT_END}" | jq -r '.data.result[0].value[1] // "N/A"')

    # Query average flow temperature for the day
    AVG_FLOW=$(curl -s "http://localhost:9090/api/v1/query?query=avg_over_time(heatpump_flow_temperature_celsius%5B1d%5D)&time=${MIDNIGHT_END}" | jq -r '.data.result[0].value[1] // "N/A"')

    # Query maximum indoor temperature for the day (for stove detection)
    # Only check 6:00 AM to midnight to avoid false positives from previous day's stove warmth
    SIX_AM=$(date -d "$DATE 06:00:00" +%s)
    TIME_RANGE=$((MIDNIGHT_END - SIX_AM))
    MAX_INDOOR=$(curl -s "http://localhost:9090/api/v1/query?query=max_over_time(sensor_temperature_celsius%7Bsensor_name%3D%22temp_indoor%22%7D%5B${TIME_RANGE}s%5D)&time=${MIDNIGHT_END}" | jq -r '.data.result[0].value[1] // "N/A"')

    # Detect stove usage: indoor max > 22.5°C AND outdoor avg < 10°C (checked only 6 AM - midnight)
    STOVE_MARKER=""
    if [[ "$MAX_INDOOR" != "N/A" && "$AVG_TEMP" != "N/A" ]]; then
        if awk -v i="$MAX_INDOOR" -v o="$AVG_TEMP" 'BEGIN{exit !(i > 22.5 && o < 10)}'; then
            STOVE_MARKER="x"
        fi
    fi

    # Count defrost cycles - only if requested.
    # Detected by the physical signature, not a power threshold: during a defrost
    # the reversing valve turns the outdoor coil into the condenser, so heat is
    # drawn OUT of the water and flow falls below return. The compressor term
    # excludes idle spells, where flow also sits below return but nothing runs.
    # Samples less than 5 min apart are one episode.
    # This replaced a "power > 8kW" rising-edge test, which only caught defrosts
    # that the backup heater assisted and missed every mild-weather one (those
    # peak near 4kW) - it scored 0 on days with 3-4 real defrost cycles.
    DEFROST_COUNT=""
    if [ "$INCLUDE_DEFROST" = true ]; then
        DEFROST_COUNT=$(curl -s -G "http://localhost:9090/api/v1/query_range" \
            --data-urlencode 'query=(heatpump_flow_temperature_celsius < heatpump_return_temperature_celsius) and on() (wago_power_total_kw > 3)' \
            --data-urlencode "start=${MIDNIGHT_START}" \
            --data-urlencode "end=${MIDNIGHT_END}" \
            --data-urlencode 'step=30' | jq '
          [.data.result[0].values[]? | .[0]] as $ts
          | if ($ts | length) == 0 then 0
            else reduce range(0; $ts | length) as $i (
                   0;
                   if $i == 0 or ($ts[$i] - $ts[$i-1]) > 300 then . + 1 else . end)
            end')
    fi

    # Calculate daily consumption
    if [[ "$START_VAL" != "N/A" && "$END_VAL" != "N/A" ]]; then
        DAILY=$(awk -v e="$END_VAL" -v s="$START_VAL" 'BEGIN{printf "%.3f", e - s}')

        # Format temperature displays
        if [[ "$AVG_TEMP" != "N/A" ]]; then
            TEMP_DISPLAY=$(printf "%.1f" "$AVG_TEMP")
        else
            TEMP_DISPLAY="N/A"
        fi
        if [[ "$AVG_FLOW" != "N/A" ]]; then
            FLOW_DISPLAY=$(printf "%.1f" "$AVG_FLOW")
        else
            FLOW_DISPLAY="N/A"
        fi

        if [ "$FORMAT" = "csv" ]; then
            if [ "$INCLUDE_DEFROST" = true ]; then
                printf "%s,%.1f,%.1f,%.1f,%s,%s,%s,%s,OK\n" "$DATE" "$START_VAL" "$END_VAL" "$DAILY" "$TEMP_DISPLAY" "$FLOW_DISPLAY" "$STOVE_MARKER" "$DEFROST_COUNT"
            else
                printf "%s,%.1f,%.1f,%.1f,%s,%s,%s,OK\n" "$DATE" "$START_VAL" "$END_VAL" "$DAILY" "$TEMP_DISPLAY" "$FLOW_DISPLAY" "$STOVE_MARKER"
            fi
        else
            if [ "$INCLUDE_DEFROST" = true ]; then
                printf "%s | %11.1f | %11.1f | %11.1f | %6s | %7s | %5s | %4s | OK\n" "$DATE" "$START_VAL" "$END_VAL" "$DAILY" "$TEMP_DISPLAY" "$FLOW_DISPLAY" "$STOVE_MARKER" "$DEFROST_COUNT"
            else
                printf "%s | %11.1f | %11.1f | %11.1f | %6s | %7s | %5s | OK\n" "$DATE" "$START_VAL" "$END_VAL" "$DAILY" "$TEMP_DISPLAY" "$FLOW_DISPLAY" "$STOVE_MARKER"
            fi
            # Accumulate for summary
            TOTAL_KWH=$(awk -v t="$TOTAL_KWH" -v d="$DAILY" 'BEGIN{printf "%.3f", t + d}')
            VALID_DAYS=$((VALID_DAYS + 1))

            # Accumulate temperature if available (check for non-zero or valid number)
            if [[ "$AVG_TEMP" != "N/A" ]] && [[ "$AVG_TEMP" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
                TOTAL_TEMP=$(awk -v t="$TOTAL_TEMP" -v a="$AVG_TEMP" 'BEGIN{printf "%.3f", t + a}')
                VALID_TEMP_DAYS=$((VALID_TEMP_DAYS + 1))
            fi
        fi
    else
        # No energy data, but may have temperature
        TEMP_DISPLAY="N/A"
        FLOW_DISPLAY="N/A"
        if [[ "$AVG_TEMP" != "N/A" ]]; then
            TEMP_DISPLAY=$(printf "%.1f" "$AVG_TEMP")
        fi
        if [[ "$AVG_FLOW" != "N/A" ]]; then
            FLOW_DISPLAY=$(printf "%.1f" "$AVG_FLOW")
        fi
        if [ "$FORMAT" = "csv" ]; then
            if [ "$INCLUDE_DEFROST" = true ]; then
                printf "%s,%s,%s,%s,%s,%s,%s,%s,NO_DATA\n" "$DATE" "$START_VAL" "$END_VAL" "N/A" "$TEMP_DISPLAY" "$FLOW_DISPLAY" "$STOVE_MARKER" "$DEFROST_COUNT"
            else
                printf "%s,%s,%s,%s,%s,%s,%s,NO_DATA\n" "$DATE" "$START_VAL" "$END_VAL" "N/A" "$TEMP_DISPLAY" "$FLOW_DISPLAY" "$STOVE_MARKER"
            fi
        else
            if [ "$INCLUDE_DEFROST" = true ]; then
                printf "%s | %11s | %11s | %11s | %6s | %7s | %5s | %4s | no data\n" "$DATE" "$START_VAL" "$END_VAL" "N/A" "$TEMP_DISPLAY" "$FLOW_DISPLAY" "$STOVE_MARKER" "$DEFROST_COUNT"
            else
                printf "%s | %11s | %11s | %11s | %6s | %7s | %5s | no data\n" "$DATE" "$START_VAL" "$END_VAL" "N/A" "$TEMP_DISPLAY" "$FLOW_DISPLAY" "$STOVE_MARKER"
            fi
        fi
    fi
done

# Print summary for table format
if [ "$FORMAT" != "csv" ] && [ $VALID_DAYS -gt 0 ]; then
    AVERAGE_KWH=$(awk -v t="$TOTAL_KWH" -v n="$VALID_DAYS" 'BEGIN{printf "%.1f", t / n}')

    # Calculate average temperature if we have data
    if [ $VALID_TEMP_DAYS -gt 0 ]; then
        AVERAGE_TEMP=$(awk -v t="$TOTAL_TEMP" -v n="$VALID_TEMP_DAYS" 'BEGIN{printf "%.1f", t / n}')
        TEMP_SUMMARY=$(printf "%.1f°C" "$AVERAGE_TEMP")
    else
        TEMP_SUMMARY="N/A"
    fi

    if [ "$INCLUDE_DEFROST" = true ]; then
        echo "-----------|-------------|-------------|-------------|--------|---------|-------|------|--------"
        printf "%-10s | %11s | %11s | %11.1f | %6s | %7s | %5s | %4s | Summary\n" "Total" "" "" "$TOTAL_KWH" "" "" "" ""
        printf "%-10s | %11s | %11s | %11.1f | %6s | %7s | %5s | %4s | (%d days)\n" "Average" "" "" "$AVERAGE_KWH" "$TEMP_SUMMARY" "" "" "" "$VALID_DAYS"
    else
        echo "-----------|-------------|-------------|-------------|--------|---------|-------|--------"
        printf "%-10s | %11s | %11s | %11.1f | %6s | %7s | %5s | Summary\n" "Total" "" "" "$TOTAL_KWH" "" "" ""
        printf "%-10s | %11s | %11s | %11.1f | %6s | %7s | %5s | (%d days)\n" "Average" "" "" "$AVERAGE_KWH" "$TEMP_SUMMARY" "" "" "$VALID_DAYS"
    fi
fi
