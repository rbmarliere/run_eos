#!/bin/sh

source $(dirname "$0")/prompt_input_yN/prompt_input_yN.sh

eos_walletd()
{
    eoscheck

    wallet=""
    if [ -f ${EOSIO_ROOT}/bin/eos-walletd ]; then
        wallet=${EOSIO_ROOT}/bin/eos-walletd
    fi
    if [ -f ${EOSIO_ROOT}/bin/eosio-walletd ]; then
        wallet=${EOSIO_ROOT}/bin/eosio-walletd
    fi
    if [ -f ${EOSIO_ROOT}/bin/eosiowd ]; then
        wallet=${EOSIO_ROOT}/bin/eosiowd
    fi
    if [ -f ${EOSIO_ROOT}/bin/keosd ]; then
        wallet=${EOSIO_ROOT}/bin/keosd
    fi
    if [ "${wallet}" = "" ]; then
        printf "error: couldn't find binary, check your eosconf\n"
        return 1
    fi

    ${wallet} \
        --http-server-address=${EOSIO_WALLET_HOST}:${EOSIO_WALLET_PORT} \
        --wallet-dir=${EOSIO_WALLET_DIR} \
        --data-dir=${EOSIO_DATA_DIR} \
        $@
}

eosc()
{
    eoscheck

    eosc=""
    if [ -f ${EOSIO_ROOT}/bin/eosc ]; then
        eosc=${EOSIO_ROOT}/bin/eosc
    fi
    if [ -f ${EOSIO_ROOT}/bin/eosioc ]; then
        eosc=${EOSIO_ROOT}/bin/eosioc
    fi
    if [ -f ${EOSIO_ROOT}/bin/cleos ]; then
        eosc=${EOSIO_ROOT}/bin/cleos
    fi
    if [ "${eosc}" = "" ]; then
        printf "error: couldn't find binary, check your eosconf\n"
        return 1
    fi

    ${eosc} \
        --host ${EOSIO_HTTP_HOST} \
        --port ${EOSIO_HTTP_PORT} \
        --wallet-host ${EOSIO_WALLET_HOST} \
        --wallet-port ${EOSIO_WALLET_PORT} \
        $@
}

eoscheck()
{
    if [ "${EOSIO_ROOT}"        = "" ] \
    || [ "${EOSIO_DATA_DIR}"    = "" ] \
    || [ "${EOSIO_CONFIG_DIR}"  = "" ] \
    || [ "${EOSIO_WALLET_DIR}"  = "" ] \
    || [ "${EOSIO_HTTP_HOST}"   = "" ] \
    || [ "${EOSIO_HTTP_PORT}"   = "" ] \
    || [ "${EOSIO_WALLET_HOST}" = "" ] \
    || [ "${EOSIO_WALLET_PORT}" = "" ] ; then
        printf "error: environment variables are null, run eosconf\n"
        return 1
    fi
}

eosconf()
{
    if [ $# -lt 8 ]; then
        printf "root: ${EOSIO_ROOT}\n"
        printf "data_dir: ${EOSIO_DATA_DIR}\n"
        printf "config_dir: ${EOSIO_CONFIG_DIR}\n"
        printf "wallet_dir: ${EOSIO_WALLET_DIR}\n"
        printf "http_host: ${EOSIO_HTTP_HOST}\n"
        printf "http_port: ${EOSIO_HTTP_PORT}\n"
        printf "wallet_host: ${EOSIO_WALLET_HOST}\n"
        printf "wallet_port: ${EOSIO_WALLET_PORT}\n\n"
        printf "usage: eosconf root data_dir config_dir wallet_dir http_host http_port wallet_host wallet_port\n"
        return 1
    fi

    export EOSIO_ROOT=$1        ; shift
    export EOSIO_DATA_DIR=$1    ; shift
    export EOSIO_CONFIG_DIR=$1  ; shift
    export EOSIO_WALLET_DIR=$1  ; shift
    export EOSIO_HTTP_HOST=$1   ; shift
    export EOSIO_HTTP_PORT=$1   ; shift
    export EOSIO_WALLET_HOST=$1 ; shift
    export EOSIO_WALLET_PORT=$1 ; shift
}

eoscpp()
{
    eoscheck

    eoscpp=""
    if [ -f ${EOSIO_ROOT}/bin/eoscpp ]; then
        eoscpp=${EOSIO_ROOT}/bin/eoscpp
    fi
    if [ -f ${EOSIO_ROOT}/bin/eosiocpp ]; then
        eoscpp=${EOSIO_ROOT}/bin/eosiocpp
    fi
    if [ "${eoscpp}" = "" ]; then
        printf "error: couldn't find binary, check your eosconf\n"
        return 1
    fi

    ${eoscpp} $@
}

eosd()
{
    eoscheck

    mkdir -p ${EOSIO_DATA_DIR}
    mkdir -p ${EOSIO_CONFIG_DIR}
    mkdir -p ${EOSIO_WALLET_DIR}

    skip=0
    while getopts "sk" OPTION; do
        case ${OPTION} in
            s ) skip=1; break;;
            k ) eosd_kill;;
        esac
    done
    if [ "${skip}" -eq 0 ]; then
        prompt_input_yN "clean" && rm -rf ${EOSIO_DATA_DIR}/{block*,shared_mem}
        prompt_input_yN "replay" && REPLAY=--replay
    fi

    eosd=""
    if [ -f ${EOSIO_ROOT}/bin/eosd ]; then
        eosd=${EOSIO_ROOT}/bin/eosd
    fi
    if [ -f ${EOSIO_ROOT}/bin/eosiod ]; then
        eosd=${EOSIO_ROOT}/bin/eosiod
    fi
    if [ -f ${EOSIO_ROOT}/bin/nodeos ]; then
        eosd=${EOSIO_ROOT}/bin/nodeos
    fi
    if [ "${eosd}" = "" ]; then
        printf "error: couldn't find binary, check your eosconf\n"
        return 1
    fi

    DATE=$(date +'%Y_%m_%d_%H_%M_%S')
    ${eosd} \
        --data-dir="${EOSIO_DATA_DIR}" \
        --config="${EOSIO_CONFIG_DIR}/config.ini" \
        --genesis-json="${EOSIO_CONFIG_DIR}/genesis.json" \
        ${REPLAY} \
        &>${EOSIO_DATA_DIR}/${DATE}.log &
    printf "$!" > ${EOSIO_DATA_DIR}/pid
    tail -f ${EOSIO_DATA_DIR}/${DATE}.log
}

eosd_kill()
{
    PID=${EOSIO_DATA_DIR}/pid
    if [ -f ${PID} ]; then
        kill -0 ${PID} && kill -2 ${PID}
    fi
}

tmux_eos()
{
    tmux_eos_nets=${tmux_eos_nets:-""}
    printf "${tmux_eos_nets}\n" | tr ' ' '\n' | while read net; do
        tmux has-session -t ${net} 2>/dev/null
        if [ $? != 0 ]; then
            tmux new-session -s ${net} -d
            tmux send-keys -t ${net} "eosconf_${net} && eos_walletd" C-m
            tmux split-window -h
            tmux send-keys -t ${net} "eosconf_${net} && eosd -s" C-m
            tmux select-pane -L
            tmux split-window -v
            tmux send-keys -t ${net} "eosconf_${net}" C-m
            tmux resize-pane -U 20
            tmux resize-pane -R 15
        fi
    done
    tmux attach
}
