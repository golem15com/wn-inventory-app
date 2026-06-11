#!/bin/bash

set -e

# Load .env from the current script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
set -a
source "$SCRIPT_DIR/.env"
set +a

DATA_DIR="$SCRIPT_DIR/typesense-data"
CONTAINER_NAME=inventory-typesense
PORT=8181

mkdir -p "$DATA_DIR"

# Kill any container using port 8108
CONFLICTING_CONTAINER=$(docker ps --filter "publish=$PORT" --format "{{.ID}}")
if [[ -n "$CONFLICTING_CONTAINER" ]]; then
    echo "Killing container using port $PORT: $CONFLICTING_CONTAINER"
    docker rm -f "$CONFLICTING_CONTAINER"
fi

# Remove stale container with same name
if docker ps -a --filter "name=$CONTAINER_NAME" --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "Removing existing container named $CONTAINER_NAME"
    docker rm -f "$CONTAINER_NAME"
fi

# Run in foreground (supervisor-friendly)
exec docker run \
    --name "$CONTAINER_NAME" \
    -p $PORT:8108 \
    -v "$DATA_DIR":/data \
    typesense/typesense:26.0 \
    --data-dir /data \
    --api-key="$TYPESENSE_API_KEY" \
    --enable-cors \
    --disable-clustering
