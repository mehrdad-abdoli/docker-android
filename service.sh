#!/bin/bash
# get all running docker container names
# usage:  start 14 0
# usage   restart Web / Android / Mobile
ports ()
{
	list=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "6080/tcp") 0).HostPort}}' $(docker ps --format "{{.ID}}" --filter name=$1))
  echo ${list[*]}| tr " " "\n" | sort -g >> ports.txt
  mv ports.txt /var/lib/docker/qa/ports/
}
GetDockerName ()
{
  containers=$(docker ps --format "{{.Names}}" --filter name=${2})
  if [[ ! -z "$containers" ]]; then
    # loop through all containers
    for container in $containers;do
      name="$(docker exec -i $container curl -s localhost:4723/wd/hub/sessions | jq -r '.value[0].capabilities.name')"
      # $(docker exec -i $container adb logcat -c)
      # name="Chat_Test_Saler_Build4221_PRstaging_1"
      if [[ $name == "${1}" ]]; then
        dockername="$container"
        break
      else
        dockername="No"
      fi
    done
  echo ${dockername}
  fi
}

Unhealthy ()
{
  containers=$(docker ps --format "{{.Names}}" --filter health=unhealthy)
  if [ ! -z "$containers" ]; then
  	echo "Restart Unhealthy Emulators"
    echo ================================
    # loop through all containers
    for container in $containers;do
			echo "Container: $container"
	    docker restart $container
      echo ================================
    done
  fi
}

restart () {
	containers=$(docker ps --format "{{.Names}}" --filter name=$1)
  if [[ ! -z "$containers" ]]; then
  	echo "Restart Emulators"
    echo ================================
    # loop through all containers
    for container in $containers;do
	    echo "Container: $container"
	    docker restart $container
      echo ================================
    done
  fi
	Unhealthy
}

HowManyHealth ()
{
	let "a = $2 + 1"
  while : ; do
    containers=$(docker ps | grep healthy | grep -v unhealthy | wc -l)
		# containers=$(docker ps --format "{{.Names}}" --filter name=$1 | grep -v unhealthy | wc -l)
    echo "healthy:$containers"
    if [[ $containers -eq $a ]]; then
      echo "healthy containers are $containers"
      break
    fi
    sleep 5;
  done;
}

restartZA () {
  cd /home/mabdoli/dockers/web
	if [ "$1" = 'up' ]; then
    : $(COMPOSE_HTTP_TIMEOUT=200 docker-compose up --force-recreate -d)
	else
    : $(docker-compose down)
	fi
}
restartMobileSite () {
  cd /home/mabdoli/dockers/mob
  : $(docker-compose down)
  # : $(docker stop $(docker ps -aq))
  # : $(docker rm $(docker ps -aq))
  : $(COMPOSE_HTTP_TIMEOUT=200 docker-compose up --scale AndroidApp=0 --scale MobileSite=$1 --remove-orphans  -d)
  : $(HowManyHealth MobileSite $1)
}
restartAndroidApp () {
  cd /home/mabdoli/dockers/mob
  : $(docker-compose down)
  : $(docker stop $(docker ps -aq))
  : $(docker rm $(docker ps -aq))
  : $(COMPOSE_HTTP_TIMEOUT=200 docker-compose up --scale AndroidApp=$1 --scale MobileSite=0 --remove-orphans  -d)
  : $(HowManyHealth AndroidApp $1)
}
QA () {
  check=$(docker exec -it mob_$2_$1  adb shell 'su 0 ls -1 /mnt/sdcard/Pictures/ | wc -l')
  if [[ $check -ne "8" ]]; then
    resp=$(docker exec -i mob_$2_$1 ./src/sheypoor.sh)
    echo $resp
  else
    echo $check
  fi
}
Images ()
{
	containers=$(docker ps --format "{{.Names}}" --filter name=$1)
	if [[ ! -z "$containers" ]]; then
		for container in $containers;do
			echo "Container: $container"
			resp=$(docker exec -i $container ./src/sheypoor.sh)
			while [[ $resp -ne "8" ]];
			do
				sleep 1;
				resp=$(docker exec -i $container ./src/sheypoor.sh)
			done;
		done
	fi
}
Finished () {
  counter=$(QA $1 $2)
  while [[ $counter -ne "8" ]];
  do
    sleep 1;
    counter=$(QA $1 $2)
  done;
  echo "8"
}
Exist () {
	exist=$(docker ps --format "{{.Names}}" --filter name=mob_$2_$1)
	if [[ $exist -eq "mob_$2_$1" ]]; then
		echo "YES"
	else
		echo "NO"
	fi
}
Health () {
  status=$(Exist $1 $2)
	if [[ $status -eq "YES" ]]; then
		containers=$(docker ps --format "{{.Names}}" --filter health=unhealthy)
		if [ ! -z "$containers" ]; then
			for container in $containers;do
				if [[ $container -eq "mob_$2_$1" ]]; then
					docker stop mob_$2_$1
          docker rm mob_$2_$1
					echo "NO"
				fi
			done
			echo "YES"
		else
			echo "YES"
		fi
	else
		echo "NO"
	fi
}
StopUnhealth () {
	containers=$(docker ps --format "{{.Names}}" --filter health=unhealthy)
	if [ ! -z "$containers" ]; then
		for container in $containers;do
			docker stop $container
      docker rm $container
		done
		count=${#container[@]}
		echo $[count-1]
  else
		echo 0
	fi
}
AndDocker () {
  if [[ -n $1 ]]; then
		stoped=$(StopUnhealth)
		if [[ $stoped -ne 0 ]];then
			START=$(($1-$stoped))
	    END=$1
	    i=$START
	    for (( c=$START; c<=$END; c++ ))
	    do
				if [ "$2" = 'AndroidApp' ]; then
					: $(COMPOSE_HTTP_TIMEOUT=200 docker-compose up -d --scale AndroidApp=$i --scale MobileSite=0 --remove-orphans)
				elif [ "$2" = 'MobileSite' ]; then
					: $(COMPOSE_HTTP_TIMEOUT=200 docker-compose up -d --scale AndroidApp=0 --scale MobileSite=$i --remove-orphans)
				else
					echo "Please specify restart kind by sending as arg to bash 1:$1 2:$2"
				fi
				ready=$(Finished $i $2)
				if [[ $ready -eq 8 ]];then
		      echo "mob_$2_$1 is ready"
		      ((i = i + 1))
		      continue
	      fi
	    done
		else
			echo "no restart needed"
		fi
  else
    echo "please send requested number of dockers"
    echo "send arg is 1:$1 2:$2"
  fi
	# Images $2
  docker restart selenium_hub
}
start ()
{
  if [[ -n $1 ]] && [[ $2 -eq 0 ]]; then
		AndDocker $1 AndroidApp
	elif [[ $1 -eq 0 ]] && [[ -n $2 ]]; then
		AndDocker $2 MobileSite
	else
		echo "Please specify correct arguments: 1:$1 2:$2"
	fi
}
AdbShell () {
	containers=$(docker ps --format "{{.Names}}" --filter name=$1)
  if [[ ! -z "$containers" ]]; then
  	echo "Run Adb Shell commands"
    echo ================================
    for container in $containers;do
	    echo "Container: $container"
      :$(docker exec  $container adb shell 'su 0 settings put secure location_providers_allowed +gps')
      :$(docker exec  $container adb shell 'su 0 settings put global window_animation_scale 0.0')
      :$(docker exec  $container adb shell 'su 0 settings put global transition_animation_scale 0.0')
      :$(docker exec  $container adb shell 'su 0 settings put global animator_duration_scale 0.0')
      :$(docker exec  $container adb shell 'su 0 settings put secure show_ime_with_hard_keyboard 0')
      docker exec  $container adb shell 'su 0 am broadcast -a com.android.intent.action.SET_LOCALE --es com.android.intent.extra.LOCALE fa_IR'
      :$(docker exec  $container adb shell 'su 0 settings put secure location_providers_allowed +gps')
      :$(docker exec  $container adb -s emulator-5554 emu geo fix 51.4 35.7  1400)
      # adb shell 'su 0 pm grant com.sheypoor.mobile android.permission.ACCESS_FINE_LOCATION'
      # adb root
      # adb shell "setprop persist.sys.language fa; setprop persist.sys.country IR; setprop ctl.restart zygote"
      echo ================================
    done
  else
    echo "No emulator found"
  fi
}
ClearGoogle () {
	containers=$(docker ps --format "{{.Names}}" --filter name=$1)
  if [[ ! -z "$containers" ]]; then
  	echo "Run Adb Shell commands"
    echo ================================
    for container in $containers;do
	    echo "Container: $container"
      docker exec $container adb shell pm clear com.google.android.ext.services
      docker exec $container adb shell pm clear com.google.android.ext.shared
      echo ================================
    done
  else
    echo "No emulator found"
  fi
}
dispatch ()
{
	if [ "$1" = 'start' ]; then
		start $2 $3
	elif [ "$1" = 'restart' ]; then
		if [ "$2" = 'Web' ]; then
			restartZA $3
    elif [ "$2" = 'MobileSite' ]; then
  		restartMobileSite $3
    elif [ "$2" = 'AndroidApp' ]; then
      restartAndroidApp $3
		else
			restart $2
		fi
	elif [ "$1" = 'unhealth' ]; then
		Unhealthy
  elif [ "$1" = 'ports' ]; then
    ports $2
  elif [ "$1" = 'shell' ]; then
    AdbShell $2
  elif [ "$1" = 'ClearGoogle' ]; then
    ClearGoogle $2
  elif [ "$1" = 'GetDockerName' ]; then
    GetDockerName $2
  elif [ "$1" = 'chromedriver' ]; then
    chromedriver
	else
		echo "Please specify commands by sending as arg to bash: 1:$1 2:$2 3:$3"
	fi
}
dispatch $1 $2 $3 $4
