#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TEMP_DIR="$REPO_ROOT/.temp"

usage() {
  cat <<EOF
Usage: db.sh <command> <target> [args]

Commands:
  copy <target>      Copy database to .temp/
  refresh <target>   Re-copy (force overwrite)
  query <target> SQL  Query the local copy
  schema <target>    Show tables and column definitions

Each project defines its own targets in the db_filename() function below.
Add cases for your project's databases there.
EOF
  exit 1
}

ensure_temp() {
  mkdir -p "$TEMP_DIR"
}

db_filename() {
  case "$1" in
    api)     echo "api.db" ;;
    crawler) echo "crawler.db" ;;
    *)       echo "Error: unknown target '$1'. Add a case for your database in db_filename()." >&2; exit 1 ;;
  esac
}

copy_api() {
  ensure_temp
  local dest="$TEMP_DIR/api.db"

  # Check Docker is running
  if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not running. Start Docker and try again." >&2
    exit 1
  fi

  # Get the API container ID
  local container
  container=$(docker compose ps -q api 2>/dev/null || true)
  if [ -z "$container" ]; then
    echo "Error: API container is not running. Run 'docker compose up' first." >&2
    exit 1
  fi

  # Copy the database from the container — adjust the container path to match your project
  if ! docker cp "$container:/app/data/api.db" "$dest" 2>/dev/null; then
    echo "Error: No database file found in container — has the API started and run migrations?" >&2
    exit 1
  fi

  echo "Copied API database to $dest"
}

copy_crawler() {
  ensure_temp
  # Adjust this path to match your project's crawler database location
  local source="$REPO_ROOT/local/crawler.db"
  local dest="$TEMP_DIR/crawler.db"

  if [ ! -f "$source" ]; then
    echo "Error: Crawler database not found at $source" >&2
    exit 1
  fi

  cp "$source" "$dest"
  echo "Copied crawler database to $dest"
}

cmd_copy() {
  case "$1" in
    api)     copy_api ;;
    crawler) copy_crawler ;;
    *)       echo "Error: unknown target '$1'. Use 'api' or 'crawler'." >&2; exit 1 ;;
  esac
}

cmd_refresh() {
  cmd_copy "$@"
}

cmd_query() {
  local target="$1"
  shift
  local sql="$*"
  local filename
  filename=$(db_filename "$target")
  local db_path="$TEMP_DIR/$filename"

  if [ ! -f "$db_path" ]; then
    echo "Error: Local copy not found at $db_path. Run 'db.sh copy $target' first." >&2
    exit 1
  fi

  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "Error: sqlite3 is not installed. Install it with 'brew install sqlite3' (macOS) or 'apt install sqlite3' (Linux)." >&2
    exit 1
  fi

  sqlite3 -header -column "$db_path" "$sql"
}

cmd_schema() {
  local target="$1"
  local filename
  filename=$(db_filename "$target")
  local db_path="$TEMP_DIR/$filename"

  if [ ! -f "$db_path" ]; then
    echo "Error: Local copy not found at $db_path. Run 'db.sh copy $target' first." >&2
    exit 1
  fi

  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "Error: sqlite3 is not installed. Install it with 'brew install sqlite3' (macOS) or 'apt install sqlite3' (Linux)." >&2
    exit 1
  fi

  echo "=== Tables ==="
  sqlite3 "$db_path" ".tables"
  echo ""
  echo "=== Schema ==="
  sqlite3 "$db_path" ".schema"
}

# Main dispatch
if [ $# -lt 2 ]; then
  usage
fi

command="$1"
target="$2"
shift 2

case "$command" in
  copy)    cmd_copy "$target" ;;
  refresh) cmd_refresh "$target" ;;
  query)   cmd_query "$target" "$@" ;;
  schema)  cmd_schema "$target" ;;
  *)       echo "Error: unknown command '$command'" >&2; usage ;;
esac
