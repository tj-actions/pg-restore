#!/usr/bin/env bash

set -e

pg_restore -Fd --dbname="$INPUT_DATABASE_URL" -j 8 "$INPUT_BACKUP_FILE"


