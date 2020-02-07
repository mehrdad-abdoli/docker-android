#!/bin/bash
containers=$(docker ps --format "{{.Names}}" --filter name=docker-android)
if [[ ! -z "$containers" ]]; then
  for container in $containers;do
    docker exec -i $container bash ./src/utils.sh

  done
echo ${dockername}
fi
