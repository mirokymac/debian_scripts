#!/bin/bash

mkdir -p /root/.cache
touch /root/.cache/NET_FAILED_COUNT
touch /root/.cache/NET_CHECKER_LOCK

FAIL_COUNT=$(</root/.cache/NET_FAILED_COUNT)
echo "FAIL_COUNT = $FAIL_COUNT"
NET_CHECKER_LOCK=$(</root/.cache/NET_CHECKER_LOCK)
if [ -z "$FAIL_COUNT" ]; then
    echo "init..."
    echo 0 > /root/.cache/NET_FAILED_COUNT
    echo 0 > /root/.cache/NET_CHECKER_LOCK
    FAIL_COUNT=0
    NET_CHECKER_LOCK=0
fi

URL="www.baidu.com"
RESP_CODES="200 301 302 404"
CONNECT=0
MAX_FAIL_COUNT=10

if [ $NET_CHECKER_LOCK -eq 0 ]; then
    echo 1 > /root/.cache/NET_CHECKER_LOCK
    echo "Testing \"$URL\""
    res=$(curl -o /dev/null -s -m 10 -w %{http_code} $URL)

    for flag in ${RESP_CODES}
    do
        if [ $flag=$res ];then
            CONNECT=$(expr $CONNECT + 1)
        fi
    done
#    CONNECT=1

    if [ $CONNECT -eq 0 ]; then
        FAIL_COUNT=$(expr $FAIL_COUNT + 1)
        echo $FAIL_COUNT > /root/.cache/NET_FAILED_COUNT
        
        if [ $FAIL_COUNT -ge $MAX_FAIL_COUNT ]; then
            if [ $FAIL_COUNT -lt $(expr $MAX_FAIL_COUNT + 1) ]; then
                echo "Too Many Failed connection count, try restarting..."
                reboot
                sleep 1
            else
                echo 3 > /root/.cache/NET_FAILED_COUNT
            fi
        fi
        echo "Try to restart network interface, the $FAIL_COUNT times...."
        iifs=$(ip link show | awk '{if(NR % 2 == 1 && $2 != "lo:"){print $2}}' | sed "s/://")
        /etc/init.d/networking restart
        for iif in ${iifs}
        do
            /sbin/ifup ${iif}
           echo " $iif up again..."
        done
        sleep 1
	echo 0 > /root/.cache/NET_CHECKER_LOCK
        exit 0
    else
        echo "Seem a good network..."
        echo 0 > /root/.cache/NET_FAILED_COUNT
    fi
    echo 0 > /root/.cache/NET_CHECKER_LOCK
else
    echo "[CAUTION!] another net checker is working now~"
    echo "I am out!"
fi
