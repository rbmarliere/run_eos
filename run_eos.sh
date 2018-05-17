#!/bin/sh

source $(dirname "$0")/prompt_input_yN/prompt_input_yN.sh

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
        printf "error: an environment variable is null, run eosconf first\n"
        return 1
    fi
    if [ ! -f ${keosd} ] \
    || [ ! -f ${cleos} ] \
    || [ ! -f ${eoscpp} ] \
    || [ ! -f ${nodeos} ]; then
        printf "error: a binary was not found in ${EOSIO_ROOT}\n"
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

    export keosd=${EOSIO_ROOT}/bin/keosd
    export cleos=${EOSIO_ROOT}/bin/cleos
    export eoscpp=${EOSIO_ROOT}/bin/eosiocpp
    export nodeos=${EOSIO_ROOT}/bin/nodeos
}

eosiocpp()
{
    eoscheck

    ${eoscpp} $@
}

keosd()
{
    eoscheck

    ${keosd} \
        --http-server-address=${EOSIO_WALLET_HOST}:${EOSIO_WALLET_PORT} \
        --wallet-dir=${EOSIO_WALLET_DIR} \
        --data-dir=${EOSIO_DATA_DIR} \
        $@
}

cleos()
{
    eoscheck

    ${cleos} \
        --url http://${EOSIO_HTTP_HOST}:${EOSIO_HTTP_PORT} \
        --wallet-url http://${EOSIO_WALLET_HOST}:${EOSIO_HTTP_PORT} \
        $@
}

nodeos()
{
    eoscheck

    mkdir -p ${EOSIO_DATA_DIR}
    mkdir -p ${EOSIO_CONFIG_DIR}
    mkdir -p ${EOSIO_WALLET_DIR}

    PID=$(cat ${EOSIO_DATA_DIR}/pid)
    skip=0
    while getopts "sk" OPTION; do
        case ${OPTION} in
            s ) skip=1; break;;
            k ) nodeos_kill ${PID}; return 1;;
        esac
    done
    if [ -d "/proc/${PID}" ]; then
        ps ef ${PID}
        printf '\n'
        prompt_input_yN "nodeos seems to be running, kill it?" && nodeos_kill ${PID} || return 1
    fi
    if [ "${skip}" -eq 0 ]; then
        prompt_input_yN "clean" && rm -rf ${EOSIO_DATA_DIR}/{block*,shared_mem}
        prompt_input_yN "replay" && REPLAY=--replay
    fi

    DATE=$(date +'%Y_%m_%d_%H_%M_%S')

    ${nodeos} \
        --data-dir="${EOSIO_DATA_DIR}" \
        --config="${EOSIO_CONFIG_DIR}/config.ini" \
        --genesis-json="${EOSIO_CONFIG_DIR}/genesis.json" \
        ${REPLAY} \
        &>${EOSIO_DATA_DIR}/${DATE}.log &

    rm -f ${EOSIO_DATA_DIR}/pid
    printf "$!" > ${EOSIO_DATA_DIR}/pid
    chmod -w ${EOSIO_DATA_DIR}/pid
    tail -f ${EOSIO_DATA_DIR}/${DATE}.log
}

nodeos_kill()
{
    PID=${1} ; shift
    kill -0 ${PID} && kill -2 ${PID}
}

tmux_eos()
{
    tmux_eos_nets=${tmux_eos_nets:-""}
    printf "${tmux_eos_nets}\n" | tr ' ' '\n' | while read net; do
        tmux has-session -t ${net} 2>/dev/null
        if [ $? != 0 ]; then
            tmux new-session -s ${net} -d
            tmux send-keys -t ${net} "eosconf_${net} && keosd" C-m
            tmux split-window -h
            tmux send-keys -t ${net} "eosconf_${net} && nodeos" C-m
            tmux select-pane -L
            tmux split-window -v
            tmux send-keys -t ${net} "eosconf_${net}" C-m
            tmux resize-pane -U 20
            tmux resize-pane -R 15
        fi
    done
    tmux attach
}

