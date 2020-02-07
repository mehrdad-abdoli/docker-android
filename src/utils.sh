#!/bin/bash

function wait_emulator_to_be_ready () {
  boot_completed=false
  while [ "$boot_completed" == false ]; do
    status=$(adb wait-for-device shell getprop dev.bootcomplete | grep "1")
    echo "Boot Status: $status"

    if [ "$status" == "1" ]; then
      boot_completed=true
    else
      sleep 10
    fi
  done
}

function change_language_if_needed() {
  if [ ! -z "${LANGUAGE// }" ] && [ ! -z "${COUNTRY// }" ]; then
    wait_emulator_to_be_ready
    echo "Language will be changed to ${LANGUAGE}-${COUNTRY}"
    adb root && adb shell "setprop persist.sys.language $LANGUAGE; setprop persist.sys.country $COUNTRY; stop; start" && adb unroot
    echo "Language is changed!"
  fi
}

function install_google_play () {
  if [ "$MOBILE_WEB_TEST" = true ]; then
    wait_emulator_to_be_ready
    echo "Google chrome will be updated"
    adb install -r "/root/src/google_chrome.apk"
  else
    # wait_emulator_to_be_ready
    # echo "Google Play Service will be installed"
    # adb install -r "/root/src/google_play_services.apk"
    # echo "Google Play Store will be installed"
    # adb install -r "/root/src/google_play_store.apk"
    echo "not now"
  fi
  # echo "Google Play Store will be installed"
  # adb install -r "/root/src/google_play_store.apk"
}

function disable_animation () {
  # To improve performance
  wait_emulator_to_be_ready
  adb shell "su root pm disable com.google.android.googlequicksearchbox"
  adb shell "settings put global window_animation_scale 0.0"
  adb shell "settings put global transition_animation_scale 0.0"
  adb shell "settings put global animator_duration_scale 0.0"
}

function enable_proxy_if_needed () {
  if [ "$ENABLE_PROXY_ON_EMULATOR" = true ]; then
    if [ ! -z "${HTTP_PROXY// }" ]; then
      if [[ $HTTP_PROXY == *"http"* ]]; then
        protocol="$(echo $HTTP_PROXY | grep :// | sed -e's,^\(.*://\).*,\1,g')"
        proxy="$(echo ${HTTP_PROXY/$protocol/})"
        echo "[EMULATOR] - Proxy: $proxy"

        IFS=':' read -r -a p <<< "$proxy"

        echo "[EMULATOR] - Proxy-IP: ${p[0]}"
        echo "[EMULATOR] - Proxy-Port: ${p[1]}"

        wait_emulator_to_be_ready
        echo "Enable proxy on Android emulator. Please make sure that docker-container has internet access!"
        adb root

        echo "Set up the Proxy"
        adb shell "content update --uri content://telephony/carriers --bind proxy:s:"${p[0]}" --bind port:s:"${p[1]}" --where "mcc=310" --where "mnc=260""

        adb unroot
      else
        echo "Please use http:// in the beginning!"
      fi
    else
      echo "$HTTP_PROXY is not given! Please pass it through environment variable!"
      exit 1
    fi
  fi
}

function QA () {
  # checker="$(adb shell 'su 0 ls /mnt/sdcard/Download/qa101.jpg > /dev/null 2>&1 && echo "yes" || echo "no"')"
  wait_emulator_to_be_ready
  resp=$(adb shell "ls -1 /mnt/sdcard/Download/ | wc -l")
  echo $resp
}

function Push () {
  wait_emulator_to_be_ready
  echo "Pushing Images :"
  touch -a -m /media/*
  adb push -p /media/* /mnt/sdcard/Download
  counter=$(QA)
  echo "Pushed images : ${counter}"
  adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///mnt/sdcard/Download
  adb shell  "ls /mnt/sdcard/Download"
}

function Fake_Geo () {
  echo "Fake Geo :Please Agree"
  adb shell "settings put secure location_providers_allowed +network"
  adb -s emulator-5554 emu geo fix 35.7 51.4 1400
}

enable_proxy_if_needed
change_language_if_needed
disable_animation
install_google_play
Fake_Geo
Push
