#!/bin/bash
app=$1
mob=$2
function wait_emulator_to_be_ready () {
  boot_completed=false
  while [ "$boot_completed" == false ]; do
    status=$(docker exec -i docker-android_$1 adb wait-for-device shell getprop dev.bootcomplete | grep "1")
    echo "Boot Status: $status"

    if [ "$status" == "1" ]; then
      boot_completed=true
    else
      sleep 5
    fi
  done
}



for i in $(seq 1 $app);
do
  COMPOSE_HTTP_TIMEOUT=200 docker-compose up --scale AndroidApp=$i --scale MobileSite=0 --remove-orphans  -d
  echo "Start $i Emulator"
  wait_emulator_to_be_ready AndroidApp_$i
done

for i in $(seq 1 $mob);
do
  COMPOSE_HTTP_TIMEOUT=200 docker-compose up --scale AndroidApp=$app --scale MobileSite=$i --remove-orphans  -d
  echo "Start $i Emulator"
  wait_emulator_to_be_ready MobileSite_$i
done
