#!/bin/bash

# We assume that these scripts are running in cygwin so we need to transfrom from unix path to windows path
BAMBOO_BACKUP_WIN_DB=$(cygpath -aw "${BAMBOO_BACKUP_DB}")

function bamboo_prepare_db {
    sqlcmd -Q "BACKUP DATABASE ${BAMBOO_DB} to disk='${BAMBOO_BACKUP_WIN_DB}'"
}

function bamboo_backup_db {
    sqlcmd -Q "BACKUP DATABASE ${BAMBOO_DB} to disk='${BAMBOO_BACKUP_WIN_DB}' WITH DIFFERENTIAL"
}

