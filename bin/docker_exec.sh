#!/usr/bin/env bash

# safe return/exit
die() {
  local code="${1:-1}"
  shift
  [ $# -gt 0 ] && echo "Error: $*"

  # If sourced, use return; otherwise use exit
  (return 0 2>/dev/null) && return "$code" || exit "$code"
}

usage() {
  echo "Usage: ${0##*/} <container_name|container_id> <command> [args...]"
  echo "Examples:"
  echo "  ${0##*/} my_container /bin/bash"
  echo "  ${0##*/} my_container python app.py"
}

# Check argument count
if [ $# -lt 2 ]; then
  usage
  die 1 "insufficient arguments"
fi

CONTAINER="$1"
shift

# Check whether docker exists
if ! command -v docker >/dev/null 2>&1; then
  die 1 "docker command not found. Please install Docker first."
fi

# Check whether container exists
if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  die 1 "container '$CONTAINER' does not exist."
fi

# Check whether container is running
RUNNING=$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)
if [ "$RUNNING" != "true" ]; then
  die 1 "container '$CONTAINER' is not running."
fi

# Execute command
docker exec -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 -it "$CONTAINER" "$@"
