#!/usr/bin/env bash
set -euo pipefail
gunzip -c "$1" | psql "$DATABASE_URL"
