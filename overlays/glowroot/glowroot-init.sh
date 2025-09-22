#!/bin/sh

set -e

if [ ! -f /opt/glowroot/glowroot.jar ]; then
  curl --location "https://github.com/glowroot/glowroot/releases/download/v$GLOWROOT_VERSION/glowroot-$GLOWROOT_VERSION-dist.zip" --output /tmp/glowroot.zip
  unzip -q /tmp/glowroot.zip -d /tmp/

  # Pick only what we need
  cp /tmp/glowroot/glowroot.jar /opt/glowroot/
  mkdir /opt/glowroot/lib/
  cp /tmp/glowroot/lib/glowroot-central-collector-https-linux.jar /opt/glowroot/lib/
  cp /tmp/glowroot/lib/glowroot-embedded-collector.jar /opt/glowroot/lib/
  cp /tmp/glowroot/lib/glowroot-logging-logstash.jar /opt/glowroot/lib/
fi

mkdir --parents /opt/glowroot/data /opt/glowroot/logs /opt/glowroot/tmp
chown --recursive "$APP_UID:$APP_GID" /opt/glowroot/data /opt/glowroot/logs /opt/glowroot/tmp

cp /tmp/admin.json /opt/glowroot/admin.json
chown "$APP_UID:$APP_GID" /opt/glowroot/admin.json

touch /opt/glowroot/config.json
chown "$APP_UID:$APP_GID" /opt/glowroot/config.json
