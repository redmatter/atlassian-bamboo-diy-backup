#!/bin/bash

function error {
    echo "[${BAMBOO_URL}] ERROR: $*"
    hc_announce "[${BAMBOO_URL}] ERROR: $*" "red" 1
}

function bail {
    error $*
    exit 99
}

function info {
    if [ "${BAMBOO_VERBOSE_BACKUP}" == "TRUE" ]; then
        echo "[${BAMBOO_URL}]  INFO: $*"
        hc_announce "[${BAMBOO_URL}]  INFO: $*" "gray"
    fi
}

function success {
    echo "[${BAMBOO_URL}]  SUCC: $*"
    hc_announce "[${BAMBOO_URL}]  SUCC: $*" "green"
}

function print {
    if [ "${BAMBOO_VERBOSE_BACKUP}" == "TRUE" ]; then
        echo "$@"
    fi
}

function check_command {
    type -P $1 &> /dev/null || bail "Unable to find $1, please install it and run this script again"
}

# $1 = message, $2 = color (yellow/green/red/purple/gray/random), $3 = notify (0/1)
function hc_announce {
    if [ -z "${HIPCHAT_ROOM}" ]; then
        return 0
    fi
    if [ -z "${HIPCHAT_TOKEN}" ]; then
        return 0
    fi

    if [ -z "$1" ]; then
        echo "ERROR: HipChat notification message is missing."
        return 1
    fi

    local COLOR="gray"
    if [ -n "$2" ]; then
        COLOR=$2
    fi
    local NOTIFY="false"
    if [ "1" == "$3" ]; then
        NOTIFY="true"
    fi

    local MESSAGE=`echo "$1" | sed -e 's|"|\\\"|g'`
    curl -s -S -X POST -H "Content-Type: application/json" -d "{\"message\":\"${MESSAGE}\",\"color\":\"${COLOR}\",\"notify\":${NOTIFY}}" "${HIPCHAT_URL}/v2/room/${HIPCHAT_ROOM}/notification?auth_token=${HIPCHAT_TOKEN}"
}
