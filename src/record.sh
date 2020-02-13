#!/bin/bash

function start() {
    PR="$(curl -s localhost:4723/wd/hub/sessions | jq -r '.value[0].capabilities.PR')"
    BUILD="$(curl -s localhost:4723/wd/hub/sessions | jq -r '.value[0].capabilities.build')"
    name="$(curl -s localhost:4723/wd/hub/sessions | jq -r '.value[0].capabilities.name')"
    mkdir -p ${VIDEO_PATH}/${PR}/${BUILD}
    echo "Start video recording"
    # ffmpeg -video_size 1598x898 -framerate 15 -f x11grab -i $DISPLAY ${VIDEO_PATH}/${PR}/${BUILD}/${name} -y
    # adb shell screenrecord --size 1598x898 --bit-rate 3000000 --time-limit 180 --bugreport /mnt/sdcard/Download/${name}
    adb shell "screenrecord --size 1598x898 --bit-rate 3000000 /mnt/sdcard/Download/${name}_1.mp4; screenrecord --size 1598x898 --bit-rate 3000000 /mnt/sdcard/Download/${name}_2.mp4; screenrecord --size 1598x898 --bit-rate 3000000 /mnt/sdcard/Download/${name}_3.mp4"
    ffmpeg -f concat -safe 0 -i <(for f in ./*.mp4; do echo "file '$PWD/$f'"; done) -c copy ${name}.mp4
		adb pull /mnt/sdcard/Download/${name}
    mv ${name} ${VIDEO_PATH}/${PR}/${BUILD}/
		adb shell rm /mnt/sdcard/Download/${name}
}

function stop() {
    echo "Stop video recording"
    kill $(ps -ef | grep [f]fmpeg | awk '{print $2}')
}

function auto_record() {
    echo "Auto record: $AUTO_RECORD"
    sleep 6

    while [ "$AUTO_RECORD" = true ]; do
        # Check if there is test running
        no_test=true
        while $no_test; do
            task=$(curl -s localhost:4723/wd/hub/sessions | jq -r '.value')
            if [ "$task" = "" ] || [ "$task" = "[]" ]; then
                sleep .5
            else
                start &
                no_test=false
            fi
        done

        # Check if test is finished
        while [ $no_test = false ]; do
            task=$(curl -s localhost:4723/wd/hub/sessions | jq -r '.value')
            if [ "$task" = "" ] || [ "$task" = "[]" ]; then
                stop
                no_test=true
            else
                sleep .5
            fi
        done
    done

    echo "Auto recording is disabled!"
}

$@
