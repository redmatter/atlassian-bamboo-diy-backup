#!/bin/bash

check_command "mysqldump"
check_command "mysqlshow"
check_command "mysql"

# Use -h option if MYSQL_HOST is set
if [[ -n ${MYSQL_HOST} ]]; then
    MYSQL_HOST_CMD="-h ${MYSQL_HOST}"
fi

function bamboo_prepare_db {
    info "Prepared backup of DB ${BAMBOO_DB} in ${BAMBOO_BACKUP_DB}"
}

function bamboo_backup_db {
    rm -r ${BAMBOO_BACKUP_DB}
    mysqldump ${MYSQL_HOST_CMD} ${MYSQL_BACKUP_OPTIONS} -u ${MYSQL_USERNAME} -p${MYSQL_PASSWORD} --databases ${BAMBOO_DB} > ${BAMBOO_BACKUP_DB}/database.sql
    if [ $? != 0 ]; then
        bail "Unable to backup ${BAMBOO_DB} to ${BAMBOO_BACKUP_DB}"
    fi
    info "Performed backup of DB ${BAMBOO_DB} in ${BAMBOO_BACKUP_DB}"
}

function bamboo_bail_if_db_exists {
    mysqlshow ${MYSQL_HOST_CMD} -u ${MYSQL_USERNAME} -p${MYSQL_PASSWORD} ${BAMBOO_DB}
    if [ $? = 0 ]; then
        bail "Cannot restore over existing database ${BAMBOO_DB}. Try renaming or droping ${BAMBOO_DB} first."
    fi
}

function bamboo_restore_db {
    mysql ${MYSQL_HOST_CMD} -u ${MYSQL_USERNAME} -p${MYSQL_PASSWORD} < ${BAMBOO_RESTORE_DB}/database.sql
    if [ $? != 0 ]; then
        bail "Unable to restore ${BAMBOO_RESTORE_DB} to ${BAMBOO_DB}"
    fi
    info "Performed restore of ${BAMBOO_RESTORE_DB} to DB ${BAMBOO_DB}"
}
