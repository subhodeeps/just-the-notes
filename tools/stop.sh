#!/usr/bin/env bash
#
# Stop the server that tools/run.sh started: the processes that listen on the
# site's port (4000) and on the live reload port (35729)

pids="$(lsof -t -iTCP:4000 -iTCP:35729 -sTCP:LISTEN | sort -u)"

if [ -z "$pids" ]; then
  echo "> No server is running"
  exit 0
fi

echo "> Stopping $(echo $pids)"
kill $pids
