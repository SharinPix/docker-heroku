#!/bin/sh
# Start Redis with the certificates baked into the image.
# REDIS_APPENDONLY, REDIS_APPENDFSYNC, and REDIS_PASSWORD still configure
# the server. Extra arguments are appended so they can override defaults.
set -eu

start_server=0
if [ "$#" -eq 0 ]; then
  start_server=1
elif [ "$1" = "redis-server" ]; then
  start_server=1
  shift
elif [ "${1#-}" != "$1" ]; then
  start_server=1
fi

if [ "$start_server" -eq 1 ]; then
  n=0
  while [ "$#" -gt 0 ]; do
    n=$((n + 1))
    eval "user_arg_$n=\$1"
    shift
  done

  set -- \
    --tls-port 6379 \
    --port 0 \
    --tls-cert-file /etc/redis/tls/redis.crt \
    --tls-key-file /etc/redis/tls/redis.key \
    --tls-ca-cert-file /etc/redis/tls/ca.crt \
    --tls-dh-params-file /etc/redis/tls/redis.dh \
    --requirepass "${REDIS_PASSWORD:-pass}" \
    --tls-auth-clients optional

  if [ -n "${REDIS_APPENDONLY:-}" ]; then
    set -- "$@" --appendonly "$REDIS_APPENDONLY"
  fi

  if [ -n "${REDIS_APPENDFSYNC:-}" ]; then
    set -- "$@" --appendfsync "$REDIS_APPENDFSYNC"
  fi

  i=1
  while [ "$i" -le "$n" ]; do
    eval "arg=\$user_arg_$i"
    set -- "$@" "$arg"
    i=$((i + 1))
  done

  set -- redis-server "$@"
fi

exec docker-entrypoint.sh "$@"
