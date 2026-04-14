# Shared utilities for .env generation scripts.
# Source this file; do not execute it directly.

_REQUIRED_COMMANDS=("tr" "head" "fold" "shuf" "sed" "chmod" "cp")

check_required_commands() {
  local missing=()
  for cmd in "${_REQUIRED_COMMANDS[@]}" "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  if [ ${#missing[@]} -ne 0 ]; then
    echo "Error: The following required commands are not available:" >&2
    printf "  - %s\n" "${missing[@]}" >&2
    echo "" >&2
    echo "Please install the missing commands and try again." >&2
    exit 1
  fi
}

_LENGTH=32
_CHARSET='A-Za-z0-9_=.-'

generate_password() {
  local password=""
  password+=$(LC_ALL=C tr -dc '[:upper:]' < /dev/urandom | head -c 1)
  password+=$(LC_ALL=C tr -dc '[:lower:]' < /dev/urandom | head -c 1)
  password+=$(LC_ALL=C tr -dc '0-9' < /dev/urandom | head -c 1)
  password+=$(LC_ALL=C tr -dc '_=.-' < /dev/urandom | head -c 1)
  local remaining=$((_LENGTH - 4))
  password+=$(LC_ALL=C tr -dc "$_CHARSET" < /dev/urandom | head -c "$remaining")
  echo "$password" | fold -w1 | shuf | tr -d '\n'
}

# Detect GNU vs BSD sed once, available to all sourcing scripts.
if sed --version >/dev/null 2>&1; then
  SED_FLAGS=(-i)
else
  SED_FLAGS=(-i '')
fi

update_env_var() {
  local file="$1"
  local key="$2"
  local value="$3"
  sed "${SED_FLAGS[@]}" "s|^${key}=.*|${key}=${value}|" "$file"
}
