#!/usr/bin/env bash
# Import démarches from a JSON file into one instance of the test stand (see DOCKER-SETUP.md).
#
# Usage, from the directory that contains both repositories:
#   por_gpp/docker/scripts/import_procedures.sh demarches-simplifiees
#   por_gpp/docker/scripts/import_procedures.sh por_gpp path/to/procedures.json
#
# The JSON file defaults to sample_procedures.json, next to this script.
# The instance's app container must be running.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTANCE_DIR="${1:?Usage: $0 <instance directory> [procedures.json]}"
JSON_FILE="${2:-${SCRIPT_DIR}/sample_procedures.json}"

if [ ! -d "$INSTANCE_DIR" ]; then
  echo "ERROR: instance directory not found: $INSTANCE_DIR" >&2
  exit 1
fi
if [ ! -f "$JSON_FILE" ]; then
  echo "ERROR: JSON file not found: $JSON_FILE" >&2
  exit 1
fi
JSON_FILE="$(cd "$(dirname "$JSON_FILE")" && pwd)/$(basename "$JSON_FILE")"

cd "$INSTANCE_DIR"
CONTAINER="$(docker compose ps -q app)"
if [ -z "$CONTAINER" ]; then
  echo "ERROR: the app container is not running in $INSTANCE_DIR" >&2
  exit 1
fi

# Copy the script and the JSON into the container, run the import, then clean up.
TMP="/tmp/import_procedures_$$"
docker cp "$SCRIPT_DIR/import_procedures.rb" "$CONTAINER:$TMP.rb"
docker cp "$JSON_FILE" "$CONTAINER:$TMP.json"
status=0
docker compose exec -T app bin/rails runner "$TMP.rb" "$TMP.json" || status=$?
docker exec -u 0 "$CONTAINER" rm -f "$TMP.rb" "$TMP.json"
exit "$status"
