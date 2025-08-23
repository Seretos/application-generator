#!/bin/bash

set -e

APP_URI="${APP_URI:=http://127.0.0.1}"
export APP_URI="${APP_URI%/}"

APP_HOST=$(echo "$APP_URI" | sed -E 's~^[a-z]+://([^:/]+).*~\1~')

NGINX_PORT="80"
NGINX_SCHEME="http"

if [[ "$APP_URI" =~ ^https:// ]]; then
  NGINX_SCHEME="https"
  NGINX_PORT="443"
fi

if [[ "$APP_URI" =~ ^https?://[^:/]+:([0-9]+) ]]; then
  NGINX_PORT="${BASH_REMATCH[1]}"
fi

export NGINX_PORT
export NGINX_SCHEME
export NGINX_ACCESS_LOG=/proc/1/fd/1
export NGINX_ERROR_LOG=/proc/1/fd/2

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

if command -v composer >/dev/null 2>&1; then
  echo "install php dependencies"
  if [ "$APP_ENV" = "prod" ]; then
    XDEBUG_MODE=off composer install --no-dev --optimize-autoloader --working-dir=./backend
  else
    XDEBUG_MODE=off composer install --working-dir=./backend
  fi
fi

mkdir -p /var/certificates
if [ ! -f "/var/certificates/nginx.key" ]; then
  echo "generate self signed ssl certificates for ${APP_HOST}"
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /var/certificates/nginx.key -out /var/certificates/nginx.crt \
    -subj "/C=DE/ST=NRW/L=Cologne/O=MyOrg/OU=Dev/CN=${APP_HOST}"
fi

envsubst '${NGINX_ACCESS_LOG} ${NGINX_ERROR_LOG} ${NGINX_SCHEME} ${NGINX_PORT}' < /github/workspace/docker/config/default.conf.template > /etc/nginx/sites-enabled/default
envsubst '${NGINX_ACCESS_LOG} ${NGINX_ERROR_LOG}' < /github/workspace/docker/config/backend.conf.template > /etc/nginx/sites-enabled/backend.conf

exec $@