#!/bin/bash

SCRIPT_DIR=$(dirname $0)

# Contains util functions (bail, info, print)
source ${SCRIPT_DIR}/bamboo.diy-backup.utils.sh

# BACKUP_VARS_FILE - allows override for bamboo.diy-backup.vars.sh
if [ -z "${BACKUP_VARS_FILE}" ]; then
    BACKUP_VARS_FILE=${SCRIPT_DIR}/bamboo.diy-backup.vars.sh
fi

# Declares other scripts which provide required backup/archive functionality
# Contains all variables used by the other scripts
if [[ -f ${BACKUP_VARS_FILE} ]]; then
    source ${BACKUP_VARS_FILE}
else
    error "${BACKUP_VARS_FILE} not found"
    bail "You should create it using ${SCRIPT_DIR}/bamboo.diy-backup.vars.sh.example as a template."
fi

# Ensure we know which user:group things should be owned as
if [[ -z ${BAMBOO_UID} || -z ${BAMBOO_GID} ]]; then
  error "Both BAMBOO_UID and BAMBOO_GID must be set in bamboo.diy-backup.vars.sh"
  bail "See bamboo.diy-backup.vars.sh.example for the defaults."
fi

# The following scripts contain functions which are dependent on the configuration of this bamboo instance.
# Generally each of them exports certain functions, which can be implemented in different ways

if [ "mssql" = "${BACKUP_DATABASE_TYPE}" ] || [ "postgresql" = "${BACKUP_DATABASE_TYPE}" ] || [ "mysql" = "${BACKUP_DATABASE_TYPE}" ]; then
    # Exports the following functions
    #     bamboo_restore_db     - for restoring the bamboo DB
    source ${SCRIPT_DIR}/bamboo.diy-backup.${BACKUP_DATABASE_TYPE}.sh
else
    error "${BACKUP_DATABASE_TYPE} is not a supported database backup type"
    bail "Please update BACKUP_DATABASE_TYPE in ${BACKUP_VARS_FILE} or consider running bamboo.diy-aws-restore.sh instead"
fi

if [ "rsync" = "${BACKUP_HOME_TYPE}" ]; then
    # Exports the following functions
    #     bamboo_restore_home   -  for restoring the filesystem backup
    source ${SCRIPT_DIR}/bamboo.diy-backup.${BACKUP_HOME_TYPE}.sh
else
    error "${BACKUP_HOME_TYPE} is not a supported home backup type"
    bail "Please update BACKUP_HOME_TYPE in ${BACKUP_VARS_FILE} or consider running bamboo.diy-aws-restore.sh instead"
fi

# Exports the following functions
#     bamboo_restore_archive - for un-archiving the archive folder
source ${SCRIPT_DIR}/bamboo.diy-backup.${BACKUP_ARCHIVE_TYPE}.sh

##########################################################
# The actual restore process. It has the following steps

function available_backups {
	echo "Available backups:"
	ls ${BAMBOO_BACKUP_ARCHIVE_ROOT}
}

if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup-file-name>.tar.gz"
    if [ ! -d ${BAMBOO_BACKUP_ARCHIVE_ROOT} ]; then
        error "${BAMBOO_BACKUP_ARCHIVE_ROOT} does not exist!"
    else
        available_backups
    fi
    exit 99
fi
BAMBOO_BACKUP_ARCHIVE_NAME=$1
if [ ! -f ${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME} ]; then
	error "${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME} does not exist!"
	available_backups
	exit 99
fi

bamboo_bail_if_db_exists

# Check and create BAMBOO_HOME
if [ -e ${BAMBOO_HOME} ]; then
	bail "Cannot restore over existing contents of ${BAMBOO_HOME}. Please rename or delete this first."
fi
mkdir -p ${BAMBOO_HOME}
chown ${BAMBOO_UID}:${BAMBOO_GID} ${BAMBOO_HOME}

# Setup restore paths
BAMBOO_RESTORE_ROOT=`mktemp -d /tmp/bamboo.diy-restore.XXXXXX`
BAMBOO_RESTORE_DB=${BAMBOO_RESTORE_ROOT}/bamboo-db
BAMBOO_RESTORE_HOME=${BAMBOO_RESTORE_ROOT}/bamboo-home

# Extract the archive for this backup
bamboo_restore_archive

# Restore the database
bamboo_restore_db

# Restore the filesystem
bamboo_restore_home

##########################################################
