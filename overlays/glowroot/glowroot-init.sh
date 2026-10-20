#!/bin/sh

set -e

if [ ! -f /opt/glowroot/glowroot.jar ]; then
  wget "https://github.com/glowroot/glowroot/releases/download/v$GLOWROOT_VERSION/glowroot-$GLOWROOT_VERSION-dist.zip" -O /tmp/glowroot.zip

  echo "${EXPECTED_SHA}  /tmp/glowroot.zip" | sha256sum -c

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

: "${GLOWROOT_ADMIN_PASSWORD:?Add GLOWROOT_ADMIN_PASSWORD to the instance .env file}"
# Same format as Glowroot's PasswordHash: base64(key):base64(salt):iterations
HASH=$(python3 -c 'import base64,hashlib,os; s=os.urandom(16); k=hashlib.pbkdf2_hmac("sha1", os.environ["GLOWROOT_ADMIN_PASSWORD"].encode(), s, 500000, 16); b=lambda x: base64.b64encode(x).decode().rstrip("="); print(f"{b(k)}:{b(s)}:500000")')
sed "s|GLOWROOT_ADMIN_PASSWORD_HASH|$HASH|" /tmp/admin.json >/opt/glowroot/admin.json
chown "$APP_UID:$APP_GID" /opt/glowroot/admin.json

touch /opt/glowroot/config.json
chown "$APP_UID:$APP_GID" /opt/glowroot/config.json
