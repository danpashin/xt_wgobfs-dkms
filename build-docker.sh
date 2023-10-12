#!/bin/bash
set -exo pipefail

NAME=xt_wgobfs-dkms

docker build -t $NAME:build .

docker container create --name  $NAME-extract $NAME:build
docker container cp $NAME-extract:/packages .
docker container rm -f $NAME-extract

docker image rm $NAME:build
