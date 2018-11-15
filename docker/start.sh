#!/bin/bash -e
mkdir -p tmp/pids/
rm -f tmp/pids/*.pid

if [ -f /run/secrets/environment ]
then
  source /run/secrets/environment
fi

exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
