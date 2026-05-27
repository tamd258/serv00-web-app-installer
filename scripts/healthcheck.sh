#!/bin/sh
set -eu
if [ "$#" -lt 3 ]; then
  echo "用法: healthcheck.sh <name> <url> <start-script>" >&2
  exit 1
fi
name="$1"
url="$2"
start_script="$3"
log="$HOME/apps/$name/health.log"
code="$(curl -L -s -o /dev/null -w '%{http_code}' "$url" || true)"
if [ "$code" != "200" ]; then
  echo "$(date '+%F %T') unhealthy: $code, restarting" >> "$log"
  sh "$start_script"
else
  echo "$(date '+%F %T') healthy: $code" >> "$log"
fi
