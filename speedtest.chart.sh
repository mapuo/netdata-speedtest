#!/bin/bash

# Netdata charts.d collector for fast.com internet speed test.
# Requires installed speedtest.com cli: `pip install speedtest-cli`
speedtest_update_every=60
speedtest_priority=100
speedtest_tmpfile="/tmp/speedtest_out.tmp"

speedtest_check() {
    require_cmd speedtest || return 1
    # flushing temporary file content to something predictable
    echo > $speedtest_tmpfile
    return 0
}


speedtest_create() {
    # create a chart with 2 dimensions
    cat <<EOF
CHART system.connectionspeed '' "System Connection Speed" "Mbps" "connection speed" system.connectionspeed line $((speedtest_priority + 1)) $speedtest_update_every
DIMENSION down 'Down' absolute 1 1000000
DIMENSION up 'Up' absolute 1 1000000
EOF

    return 0
}

speedtest_update() {
    # get the up and down speed from the previously executed . Parse them into separate values, and drop the Mbps.
    speedtest_output=$(cat $speedtest_tmpfile)
    # collect speed test results in background
    speedtest --single --csv > $speedtest_tmpfile &

    down=0
    up=0
    if [ -n "$speedtest_output" ]; then
        down=$(echo "$speedtest_output" | cut -d ',' -f 7 | cut -d '.' -f 1)
        up=$(echo "$speedtest_output" | cut -d ',' -f 8 | cut -d '.' -f 1)
    fi

    # write the result of the work.
    cat <<VALUESEOF
BEGIN system.connectionspeed
SET down = $down
SET up = $up
END
VALUESEOF

    return 0
}
