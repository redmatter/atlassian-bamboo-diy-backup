#!/bin/bash

check_command "pg_dump"
check_command "psql"
check_command "pg_restore"

# Make use of PostgreSQL 9.3+ options if available
psql_version="$(psql --version | awk '{print $3}')"
psql_majorminor="$(printf "%d%03d" $(echo "$psql_version" | tr "." "\n" | head -n 2))"
if [[ $psql_majorminor -ge 9003 ]]; then
    PG_PARALLEL="-j 5"
    PG_SNAPSHOT_OPT="--no-synchronized-snapshots"
fi

# Use username if configured
if [[ -n ${POSTGRES_USERNAME} ]]; then
    PG_USER="-U ${POSTGRES_USERNAME}"
fi

# Use password if configured
if [[ -n ${POSTGRES_PASSWORD} ]]; then
    export PGPASSWORD="${POSTGRES_PASSWORD}"
fi

# Use -h option if POSTGRES_HOST is set
if [[ -n ${POSTGRES_HOST} ]]; then
    PG_HOST="-h ${POSTGRES_HOST}"
fi

# Default port
if [[ -z ${POSTGRES_PORT} ]]; then
    POSTGRES_PORT=5432
fi

function bamboo_prepare_db {
    info "Prepared backup of DB ${BAMBOO_DB} in ${BAMBOO_BACKUP_DB}"
}

function bamboo_backup_db {
    rm -r ${BAMBOO_BACKUP_DB}
    pg_dump ${PG_USER} ${PG_HOST} --port=${POSTGRES_PORT} ${PG_PARALLEL} -Fd ${BAMBOO_DB} ${PG_SNAPSHOT_OPT} -f ${BAMBOO_BACKUP_DB}
    if [ $? != 0 ]; then
        bail "Unable to backup ${BAMBOO_DB} to ${BAMBOO_BACKUP_DB}"
    fi
    info "Performed backup of DB ${BAMBOO_DB} in ${BAMBOO_BACKUP_DB}"
}

function bamboo_bail_if_db_exists {
    psql ${PG_USER} ${PG_HOST} --port=${POSTGRES_PORT} -d ${BAMBOO_DB} -c '' > /dev/null 2>&1
    if [ $? = 0 ]; then
        bail "Cannot restore over existing database ${BAMBOO_DB}. Try dropdb ${BAMBOO_DB} first."
    fi
}

function bamboo_restore_db {
    pg_restore ${PG_USER} ${PG_HOST} --port=${POSTGRES_PORT} -d postgres -C -Fd ${PG_PARALLEL} ${BAMBOO_RESTORE_DB}
    if [ $? != 0 ]; then
        bail "Unable to restore ${BAMBOO_RESTORE_DB} to ${BAMBOO_DB}"
    fi
    info "Performed restore of ${BAMBOO_RESTORE_DB} to DB ${BAMBOO_DB}"
}
