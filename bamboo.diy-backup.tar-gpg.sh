#!/bin/bash

check_command "tar"
check_command "gpg-zip"

: ${BAMBOO_BACKUP_GPG_MODE:=asymmetric}
: ${BAMBOO_BACKUP_GPG_RECIPIENT:=}
: ${BAMBOO_BACKUP_GPG_PASSPHRASE:=}

function check_gpg_encryption_options {
    case "${BAMBOO_BACKUP_GPG_MODE}" in
        asymmetric)
            if [[ -z ${BAMBOO_BACKUP_GPG_RECIPIENT} ]]; then
                bail "In order to encrypt the backup you must set the 'BAMBOO_BACKUP_GPG_RECIPIENT' configuration variable. Exiting..."
            fi
            ;;
        symmetric)
            if [[ -z ${BAMBOO_BACKUP_GPG_PASSPHRASE} ]]; then
                bail "In order to encrypt the backup you must set the 'BAMBOO_BACKUP_GPG_PASSPHRASE' configuration variable. Exiting..."
            fi
            ;;
        *)
            bail "Unknown encryption option; you must set the 'BAMBOO_BACKUP_GPG_MODE' configuration variable correctly. Exiting..."
            ;;
    esac
}

function bamboo_backup_archive {

    check_gpg_encryption_options

    mkdir -p ${BAMBOO_BACKUP_ARCHIVE_ROOT}
    BAMBOO_BACKUP_ARCHIVE_NAME=$(perl -we 'use Time::Piece; my $sydTime = localtime; print "bamboo-", $sydTime->strftime("%Y%m%d-%H%M%S-"), substr($sydTime->epoch, -3), ".tar.gz.gpg"')

    info "Archiving ${BAMBOO_BACKUP_ROOT} into ${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME}"
    info "Encrypting for ${BAMBOO_BACKUP_GPG_RECIPIENT}"
    (
        # in a subshell to avoid changing working dir on the caller
        cd ${BAMBOO_BACKUP_ROOT}
        if [ "${BAMBOO_BACKUP_GPG_MODE}" = asymmetric ]; then
            gpg-zip --encrypt --recipient ${BAMBOO_BACKUP_GPG_RECIPIENT} \
                --output ${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME} .
        else
            echo "${BAMBOO_BACKUP_GPG_PASSPHRASE}" | gpg-zip --encrypt --symmetric \
                --output ${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME} \
                --gpg-args "--passphrase-fd 0" \
                .
        fi
    ) && 
        info "Archived ${BAMBOO_BACKUP_ROOT} into ${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME}" ||
        bail "Archiving into ${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME} failed"
}

function bamboo_restore_archive {

    check_gpg_encryption_options

    if [ -f ${BAMBOO_BACKUP_ARCHIVE_NAME} ]; then
        BAMBOO_BACKUP_ARCHIVE_NAME=${BAMBOO_BACKUP_ARCHIVE_NAME}
    else
        BAMBOO_BACKUP_ARCHIVE_NAME=${BAMBOO_BACKUP_ARCHIVE_ROOT}/${BAMBOO_BACKUP_ARCHIVE_NAME}
    fi

    if [ "${BAMBOO_BACKUP_GPG_MODE}" = asymmetric ]; then
        gpg-zip --tar-args "-C ${BAMBOO_RESTORE_ROOT}" --decrypt ${BAMBOO_BACKUP_ARCHIVE_NAME}
    else
        echo "${BAMBOO_BACKUP_GPG_PASSPHRASE}" | gpg-zip --decrypt --tar-args "-C ${BAMBOO_RESTORE_ROOT}" \
            --gpg-args "--passphrase-fd 0" \
            ${BAMBOO_BACKUP_ARCHIVE_NAME}
    fi

    info "Extracted ${BAMBOO_BACKUP_ARCHIVE_NAME} into ${BAMBOO_RESTORE_ROOT}"
}
