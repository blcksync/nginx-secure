#!/bin/bash

curr_dir=$(cd $(dirname $0); pwd)
PROD_CODE=${PROD_CODE:-""}
NGINX_CONF=${NGINX_CONF:-""}
SRC_DOCKER_DEPLOY_DIR="$curr_dir/prod"
SRC_DOCKER_NGINX_CONF_DIR="$curr_dir/myconf"
SRC_DOCKER_NGINX_LOG_DIR="$curr_dir/logs"

[ -f $curr_dir/common.sh ] && source "$curr_dir/common.sh"
export NGINX_USER=${NGINX_USER:-"nginx"}
export NGINX_UID=${NGINX_UID:-4999}
export NGINX_GID=${NGINX_GID:-5999}

IMG_NAME=securenginx:latest
RUNTIME_CONTAINER_NAME=securenginx:latest

mkdir -p "$SRC_DOCKER_DEPLOY_DIR" && rsync -av "$PROD_CODE" "$SRC_DOCKER_DEPLOY_DIR"
mkdir -p "$SRC_DOCKER_NGINX_CONF_DIR" && rsync -av "$NGINX_CONF" "$SRC_DOCKER_NGINX_CONF_DIR"
# This allows docker internal UID to write to this directory
mkdir -p "$SRC_DOCKER_NGINX_LOG_DIR" && chmod -R 1777 "$SRC_DOCKER_NGINX_LOG_DIR"

docker run -it \
  --rm \
  --label $RUNTIME_CONTAINER_NAME \
  --env NGINX_USER="$NGINX_USER" \
  --env NGINX_UID="$NGINX_UID" \
  --env NGINX_GID="$NGINX_GID" \
  --mount type=bind,source="$SRC_DOCKER_DEPLOY_DIR",target=/usr/share/nginx/html,readonly \
  --mount type=bind,source="$SRC_DOCKER_NGINX_CONF_DIR",target=/etc/nginx,readonly \
  --mount type=bind,source="$SRC_DOCKER_NGINX_LOG_DIR",target=/var/log/nginx \
  --publish 80:8080 \
  --publish 443:4443 \
  $IMG_NAME
  bash -l
