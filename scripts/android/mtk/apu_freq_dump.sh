#!/bin/bash

set -x

PLATFORM_RAW="$1"
LOOP_COUNT="${2:-5}"

if [ -z "$PLATFORM_RAW" ]; then
    echo "Usage: $0 <platform> [loop_count]"
    echo ""
    echo "Supported platforms:"
    echo "  MT6853"
    echo "  MT6877"
    echo "  MT6893"
    echo "  D1300"
    echo "  MT6889"
    echo "  MT6885"
    echo "  MT6899"
    echo "  MT6983"
    echo "  MT6985"
    echo "  MT6886"
    echo "  MT6989"
    echo ""
    echo "Example:"
    echo "  $0 MT6983"
    echo "  $0 mt6983 10"
    exit 1
fi

PLATFORM="$(echo "$PLATFORM_RAW" | tr '[:lower:]' '[:upper:]')"

if ! [[ "$LOOP_COUNT" =~ ^[0-9]+$ ]] || [ "$LOOP_COUNT" -le 0 ]; then
    echo "Invalid loop_count: $LOOP_COUNT"
    echo "loop_count must be a positive integer."
    exit 1
fi

echo "========================================"
echo "Platform   : $PLATFORM"
echo "Loop count : $LOOP_COUNT"
echo "========================================"

case "$PLATFORM" in
    MT6853|MT6877|MT6893|D1300|MT6889|MT6885)
        echo "[Step 1] Restarting adbd as root"
        adb root

        echo "[Step 2] Dumping OPP table"
        adb shell "echo opp_table 1 > /d/apusys/power"
        adb shell "cat /d/apusys/power"

        echo ""
        echo "Please enter the AI test scenario manually."
        #read -p "After entering the AI test scenario, press Enter to continue..."

        echo "[Step 3] Reading real-time APU frequency ($LOOP_COUNT times)"
        for ((i=1; i<=LOOP_COUNT; i++)); do
            echo "---------- Iteration $i/$LOOP_COUNT ----------"
            adb shell "cat /d/apusys/power"
            echo ""
            sleep 1
        done
        ;;

    MT6983)
        echo "[Step 1] Dumping OPP table"
        adb shell "echo dump_opp_tbl 1 > /d/apusys/power ; cat /d/apusys/power"

        echo ""
        echo "Please enter the AI test scenario manually."
        read -p "After entering the AI test scenario, press Enter to continue..."

        echo "[Step 2] Enabling real-time APU frequency output"
        adb shell "echo 5 7 2 0 0 > /sys/module/apu_top/parameters/aputop_func_sel"

        echo "[Step 3] Reading real-time APU frequency ($LOOP_COUNT times)"
        for ((i=1; i<=LOOP_COUNT; i++)); do
            echo "---------- Iteration $i/$LOOP_COUNT ----------"
            adb shell "cat /proc/apusys_logger/seq_logl | grep conn"
            echo ""
            sleep 1
        done
        ;;

    MT6985|MT6886|MT6899|MT6989)
        echo "[Step 1] Dumping OPP table"
        adb shell "echo dump_opp_tbl 1 > /d/apusys/power"
        adb shell "echo dump_opp_tbl2 1 > /d/apusys/power"
        adb shell "cat /d/apusys/power"

        echo ""
        echo "Please enter the AI test scenario manually."
        read -p "After entering the AI test scenario, press Enter to continue..."

        echo "[Step 2] Enabling real-time APU frequency output"
        adb shell "echo 5 7 2 0 0 > /sys/module/apu_top/parameters/aputop_func_sel"

        echo "[Step 3] Reading real-time APU frequency ($LOOP_COUNT times)"
        adb shell "cat /proc/apusys_logger/seq_logl | grep conn"
        ;;

    *)
        echo "Unsupported platform: $PLATFORM_RAW"
        exit 1
        ;;
esac

echo ""
echo "Done."

