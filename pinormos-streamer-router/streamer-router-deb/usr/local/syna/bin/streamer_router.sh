#!/bin/bash

targetVersion='3.2.0'

sourcePath=/usr/local/syna/bin/android/report_streamer

targetPath=/data

marker=/tmp/.android.connected

suParam='-c'

connection=-1

function compareVersions () {
    if [[ $1 == $2 ]]; then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]; then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done
    return 0
}

function installReportStreamer {
    armVersion=$(adb shell "su $suParam getprop ro.product.cpu.abi")
    adb push $sourcePath/$armVersion/report_streamer /sdcard && \
    adb shell "su $suParam mv /sdcard/report_streamer $targetPath" && \
    adb shell "su $suParam chmod 755 $targetPath/report_streamer"
}

function runReportStreamer {
    adb shell "su $suParam whoami" 1>/dev/null 2>&1
    if [ $? -ne 0 ]; then
        suParam='0'
    fi

    pid=$(adb shell "su $suParam ps -e | grep report_streamer" | awk '{print $2}')
    if [ ! -z "$pid" ]; then
        # kill existing Report Streamer instance
        adb shell "su $suParam kill $pid"
    fi

    if [ -z "$(adb shell "su $suParam ls $targetPath/report_streamer 2>/dev/null")" ]; then
        # missing Report Streamer executable
        installReportStreamer
        if [ $? -ne 0 ]; then
            return 1
        fi
    else
        version=$(adb shell "su $suParam $targetPath/report_streamer")
        version=$(echo $version | sed -n -e 's/^.*version\S* //p' | awk '{print $1}')
        compareVersions $version $targetVersion
        if [ $? -eq 2 ]; then
            # outdated Report Streamer executable
            installReportStreamer
            if [ $? -ne 0 ]; then
                return 1
            fi
        fi
    fi

    adb shell "su $suParam $targetPath/report_streamer 1729 1>/dev/null 2>&1 &" &
}

function killProcess {
    pid=$(ps -ef | grep $1 | grep -v grep | awk '{print $2}')
        if [ ! -z "$pid" ]; then
            sudo kill ${pid}
        fi
}

function checkConnection {
    if adb get-state 1>/dev/null 2>&1; then
        if [ $connection -eq -1 ] || [ $connection -eq 0 ]; then
        killProcess ncat
        systemctl is-active report_streamer > /dev/null 2>&1 && sudo systemctl stop report_streamer
        ncat -k -l -p 1729 -c "ncat 127.0.0.1 1730" &
        adb forward tcp:1730 tcp:1729
        runReportStreamer
        if [ $? -eq 0 ]; then
            sudo touch $marker
        fi
        connection=1
        echo "connected to remote Android device"
        fi
    else
        if [ $connection -eq -1 ] || [ $connection -eq 1 ]; then
        sudo rm -fr $marker
        killProcess ncat
        systemctl is-active report_streamer > /dev/null 2>&1 && sudo systemctl stop report_streamer
        sudo systemctl start report_streamer.service
        connection=0
        echo "connected to local development board"
        fi
    fi
}

sudo rm -fr $marker

while true; do
    checkConnection
    sleep 0.2
done
