"""Write Glowroot's admin.json with a single password-protected administrator.

Glowroot falls back to an anonymous administrator when admin.json defines no
named users, so the UI must never start without one.
"""

import base64
import hashlib
import json
import os
import sys

SOURCE = "/tmp/admin.json"
TARGET = "/opt/glowroot/admin.json"

# Matches org.glowroot.common2.repo.PasswordHash in Glowroot 0.14.
ITERATIONS = 500000
SALT_BYTES = 16
KEY_BYTES = 16

ADMIN_ROLE = "Administrator"
ADMIN_PERMISSIONS = ["agent:transaction", "agent:error", "agent:jvm", "agent:incident", "agent:config", "admin"]


def b64(data):
    return base64.b64encode(data).decode("ascii").rstrip("=")


def password_hash(password):
    salt = os.urandom(SALT_BYTES)
    key = hashlib.pbkdf2_hmac("sha1", password.encode("latin-1"), salt, ITERATIONS, KEY_BYTES)
    return f"{b64(key)}:{b64(salt)}:{ITERATIONS}"


password = os.environ.get("GLOWROOT_ADMIN_PASSWORD", "")
if not password:
    sys.exit("Error: GLOWROOT_ADMIN_PASSWORD is not set. Add it to the instance .env file.")

with open(SOURCE) as f:
    config = json.load(f)

config["users"] = [{"username": "admin", "passwordHash": password_hash(password), "roles": [ADMIN_ROLE]}]
config["roles"] = [{"name": ADMIN_ROLE, "permissions": ADMIN_PERMISSIONS}]

with open(TARGET, "w") as f:
    json.dump(config, f, indent=2)
