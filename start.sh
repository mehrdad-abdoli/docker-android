#!/bin/bash
function wait_emulator_to_be_ready () {
  boot_completed=false
  while [ "$boot_completed" == false ]; do
    status=$(docker exec -i docker-android_$1 adb wait-for-device shell getprop sys.boot_completed | tr -d '\r')
    echo "Boot Status: $status"

    if [ "$status" == "1" ]; then
      boot_completed=true
    else
      sleep 1
    fi
  done
}

docker-compose down

COMPOSE_HTTP_TIMEOUT=200 docker-compose up --scale AndroidApp=0 --scale MobileSite=0 --remove-orphans  -d
sleep 10

for i in {1..15}
do
  COMPOSE_HTTP_TIMEOUT=200 docker-compose up --scale AndroidApp=$i --scale MobileSite=0 --remove-orphans  -d
  echo "Start $i Emulator"
  wait_emulator_to_be_ready AndroidApp_$i
done

for i in {1..3}
do
  COMPOSE_HTTP_TIMEOUT=200 docker-compose up --scale AndroidApp=8 --scale MobileSite=$i --remove-orphans  -d
  echo "Start $i Emulator"
  wait_emulator_to_be_ready MobileSite_$i
done
