#!/bin/bash

SCRIPT_DIR=$(dirname $0)

# Contains util functions (bail, info, print)
source ${SCRIPT_DIR}/bamboo.diy-backup.utils.sh

# BACKUP_VARS_FILE - allows override for bamboo.diy-aws-backup.vars.sh
if [ -z "${BACKUP_VARS_FILE}" ]; then
    BACKUP_VARS_FILE=${SCRIPT_DIR}/bamboo.diy-aws-backup.vars.sh
fi

# Declares other scripts which provide required backup/archive functionality
# Contains all variables used by the other scripts
if [[ -f ${BACKUP_VARS_FILE} ]]; then
    source ${BACKUP_VARS_FILE}
else
    error "${BACKUP_VARS_FILE} not found"
    bail "You should create it using ${SCRIPT_DIR}/bamboo.diy-aws-backup.vars.sh.example as a template."
fi

# The following scripts contain functions which are dependent on the configuration of this bamboo instance.
# Generally each of them exports certain functions, which can be implemented in different ways

# Contains common functionality related to Bamboo
source ${SCRIPT_DIR}/bamboo.diy-backup.common.sh

# Exports aws specific function to be used during the restore
source ${SCRIPT_DIR}/bamboo.diy-backup.ec2-common.sh

if [ "ebs-collocated" == "${BACKUP_DATABASE_TYPE}" ] || [ "rds" == "${BACKUP_DATABASE_TYPE}" ]; then
    # Exports the following functions
    #     bamboo_restore_db     - for restoring the bamboo DB
    source ${SCRIPT_DIR}/bamboo.diy-backup.${BACKUP_DATABASE_TYPE}.sh
else
    error "${BACKUP_DATABASE_TYPE} is not a supported AWS database backup type"
    bail "Please update BACKUP_DATABASE_TYPE in ${BACKUP_VARS_FILE} or consider running bamboo.diy-restore.sh instead"
fi

if [ "ebs-home" == "${BACKUP_HOME_TYPE}" ]; then
    # Exports the following functions
    #     bamboo_restore_home   -  for restoring the filesystem backup
    source ${SCRIPT_DIR}/bamboo.diy-backup.${BACKUP_HOME_TYPE}.sh
else
    error "${BACKUP_HOME_TYPE} is not a supported AWS home backup type"
    bail "Please update BACKUP_HOME_TYPE in ${BACKUP_VARS_FILE} or consider running bamboo.diy-restore.sh instead"
fi

if [ $# -ne 1 ]; then
    info "Usage: $0 <snapshot-tag>"

    list_available_ebs_snapshot_tags

    exit 99
else
    info "Restoring from tag ${1}"
fi

##########################################################
# The actual restore process. It has the following steps

bamboo_prepare_home_restore "${1}"
bamboo_prepare_db_restore "${1}"

# Restore the database
bamboo_restore_db

# Restore the filesystem
bamboo_restore_home

success "Successfully completed the restore of your ${PRODUCT} instance"

##########################################################
