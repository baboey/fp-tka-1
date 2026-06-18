#!/bin/bash
# scripts/reset_db.sh

# Find docker-compose file location relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_SRC_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Resetting Database to Seed Dump ==="
# Execute docker compose exec
docker compose -f "$PROJECT_SRC_DIR/compose.yaml" exec -T mongo mongorestore \
  -u root -p root --authenticationDatabase admin \
  --drop /dump/
echo "=== Database Reset Completed ==="
