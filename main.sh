#!/usr/bin/env bash

set -e

pg_restore -Fd -j 8 "$INPUT_BACKUP_FILE" "$INPUT_DATABASE_URL"


