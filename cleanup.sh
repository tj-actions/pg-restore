#!/usr/bin/env bash

set -e

pg_dump -Fc -Z 9 -O -f "$INPUT_BACKUP_FILE" "$INPUT_DATABASE_URL"
