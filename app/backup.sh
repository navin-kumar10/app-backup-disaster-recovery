#!/usr/bin/env bash
set -euo pipefail
pg_dump "$DATABASE_URL" | gzip > "backup-$(date +%F).sql.gz"
