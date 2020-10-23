#!/usr/bin/env bash

set -e

pg_restore "$INPUT_RESTORE_PRE_ARGS" -d "$INPUT_DATABASE_URL" "$INPUT_BACKUP_FILE"
