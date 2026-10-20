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

# Hash the password the way Glowroot's PasswordHash does: base64(key):base64(salt):iterations
HASH=$(
  python3 - <<'EOF'
import base64, hashlib, os

def b64(data):
    return base64.b64encode(data).decode().rstrip("=")

iterations = 500000
salt = os.urandom(16)
key = hashlib.pbkdf2_hmac("sha1", os.environ["GLOWROOT_ADMIN_PASSWORD"].encode(), salt, iterations, dklen=16)
print(f"{b64(key)}:{b64(salt)}:{iterations}")
EOF
)

sed "s|GLOWROOT_ADMIN_PASSWORD_HASH|$HASH|" /tmp/admin.json >/opt/glowroot/admin.json
chown "$APP_UID:$APP_GID" /opt/glowroot/admin.json

touch /opt/glowroot/config.json
chown "$APP_UID:$APP_GID" /opt/glowroot/config.json
