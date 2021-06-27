#!/bin/bash

# Netdata charts.d collector for fast.com internet speed test.
# Requires installed speedtest.com cli: `pip install speedtest-cli`
speedtest_update_every=60
speedtest_priority=100
speedtest_tmpfile="/tmp/speedtest_out.tmp"
speedtest_server=

speedtest_check() {
    require_cmd speedtest || return 1
    require_cmd bc || return 1
    require_cmd xargs || return 1
    # Find the server from the list
    server=$(speedtest --list | grep -m 1 "$speedtest_server" | cut -d ')' -f 1 | xargs)
    # Set the server id
    speedtest_server=$server
    # flushing temporary file content to something predictable
    echo > $speedtest_tmpfile
    return 0
}


speedtest_create() {
    # create a chart with 2 dimensions and chart for latency
    cat <<EOF
CHART system.connectionspeed '' "System Connection Speed" "Mbps" "connection speed" system.connectionspeed area $((speedtest_priority + 1)) $speedtest_update_every
DIMENSION down 'Down' absolute 1 1000000
DIMENSION up 'Up' absolute 1 1000000
CHART system.connectionlatency '' "Connection Latency" "ms" "connection speed" system.connectionspeed line $((speedtest_priority + 1)) $speedtest_update_every
DIMENSION latency 'Latency' absolute 1 1000
EOF

    return 0
}

speedtest_update() {
    # get the up and down speed from the previously executed . Parse them into separate values, and drop the Mbps.
    speedtest_output=$(cat $speedtest_tmpfile)
    # collect speed test results in background
    server=${speedtest_server:+" --server $speedtest_server"}
    (speedtest --single --csv $server 2> /dev/null || speedtest --single --csv) | echo $(cat -) > $speedtest_tmpfile &

    down=0
    up=0
    latency=0
    if [ -n "$speedtest_output" ]; then
        down=$(echo "$speedtest_output" | cut -d ',' -f 7 | cut -d '.' -f 1)
        up=$(echo "$speedtest_output" | cut -d ',' -f 8 | cut -d '.' -f 1)
        latency=$(echo "$speedtest_output" | cut -d ',' -f 6 | echo "$(cat -) * 1000" | bc)
    fi

    # write the result of the work.
    cat <<VALUESEOF
BEGIN system.connectionspeed
SET down = $down
SET up = -$up
END
BEGIN system.connectionlatency
SET latency = $latency
END
VALUESEOF

    return 0
}
