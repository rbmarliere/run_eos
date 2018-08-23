#!/bin/sh

source $(dirname "$0")/prompt_input_yN/prompt_input_yN.sh

eosiocheck()
{
    if [ "${EOSIO_ROOT}"  = "" ] \
    || [ "${EOSIO_CROOT}" = "" ] \
    || [ "${EOSIO_URL}"   = "" ] \
    || [ "${EOSIO_WURL}"  = "" ]; then
        printf "error: an environment variable is null, check your eosioconf\n"
        return 1
    fi
    if [ ! -f "${keosd}" ] \
    || [ ! -f "${cleos}" ] \
    || [ ! -f "${nodeos}" ]; then
        printf "error: a binary was not found in ${EOSIO_ROOT}, check your eosioconf\n"
        return 1
    fi
}

eosioconf()
{
    if [ $# -lt 4 ]; then
        printf "usage: eosioconf eosio_root chain_root url wallet_url\n"
        printf "e.g. eosioconf /usr/local ~/eos_localnet http://127.0.0.1:8888 http://127.0.0.1:9999\n\n"
        printf "eosio_root: ${EOSIO_ROOT}\n"
        printf "chain_root: ${EOSIO_CROOT}\n"
        printf "url: ${EOSIO_URL}\n"
        printf "wallet_url: ${EOSIO_WURL}\n"
        return 1
    fi

    export EOSIO_ROOT=$1  ; shift
    export EOSIO_CROOT=$1 ; shift
    export EOSIO_URL=$1   ; shift
    export EOSIO_WURL=$1  ; shift

    export keosd=$(find ${EOSIO_ROOT} -type f -iname keosd)
    export cleos=$(find ${EOSIO_ROOT} -type f -iname cleos)
    export eosiocpp=$(find ${EOSIO_ROOT} -type f -iname eosiocpp)
    export nodeos=$(find ${EOSIO_ROOT} -type f -iname nodeos)
}

eosiocpp()
{
    eosiocheck || return 1
    ${eosiocpp} $@
}

keosd()
{
    eosiocheck || return 1
    ${keosd} --http-server-address=${EOSIO_WURL} $@
}

cleos()
{
    eosiocheck || return 1
    ${cleos} \
        --url ${EOSIO_URL} \
        --wallet-url ${EOSIO_WURL} \
        $@
}

nodeos()
{
    eosiocheck || return 1

    mkdir -p ${EOSIO_CROOT}/{config,data,log}

    if [ -f "${EOSIO_CROOT}/data/pid" ]; then
        PID=$(cat ${EOSIO_CROOT}/data/pid)
        if [ -d "/proc/${PID}" ]; then
            ps ef ${PID}
            printf '\n'
            if prompt_input_yN "nodeos seems to be running, kill it?"; then
                nodeos_kill ${PID}
            else
                tail -f ${EOSIO_CROOT}/log/lastlog
                return 1
            fi
        fi
    fi

    prompt_input_yN "clean" && rm -rf ${EOSIO_CROOT}/data/{block*,shared_mem,state}
    prompt_input_yN "replay" && REPLAY=--replay || REPLAY=
    [ -f ${EOSIO_CROOT}/data/blocks/blocks.log ] && GENESIS= || GENESIS=--genesis-json="${EOSIO_CROOT}/config/genesis.json"

    DATE=$(date +'%Y_%m_%d_%H_%M_%S')

    nohup ${nodeos} \
        --data-dir="${EOSIO_CROOT}/data" \
        --config="${EOSIO_CROOT}/config/config.ini" \
        ${GENESIS} \
        ${REPLAY} \
        $@ \
        < /dev/null \
        2>&1 \
        > ${EOSIO_CROOT}/log/${DATE}.log \
        &

    [ -L ${EOSIO_CROOT}/log/lastlog ] && unlink ${EOSIO_CROOT}/log/lastlog
    ln -s ${EOSIO_CROOT}/log/${DATE}.log ${EOSIO_CROOT}/log/lastlog

    rm -f ${EOSIO_CROOT}/data/pid
    printf "$!" > ${EOSIO_CROOT}/data/pid
    chmod -w ${EOSIO_CROOT}/data/pid

    tail -f ${EOSIO_CROOT}/log/lastlog
}

nodeos_kill()
{
    PID=${1} ; shift
    kill -0 ${PID} && kill -2 ${PID} && rm -f ${EOSIO_CROOT}/data/pid
    wait ${PID}
}

tmux_eos()
{
    tmux_eos_nets=${tmux_eos_nets:-""}
    printf "${tmux_eos_nets}\n" | tr ' ' '\n' | while read net; do
        tmux has-session -t ${net} 2>/dev/null
        if [ $? != 0 ]; then
            tmux new-session -s ${net} -d
            tmux send-keys -t ${net} "eosioconf_${net} && keosd" C-m
            tmux split-window -h
            tmux send-keys -t ${net} "eosioconf_${net} && nodeos" C-m
            tmux select-pane -L
            tmux split-window -v
            tmux send-keys -t ${net} "eosioconf_${net}" C-m
            tmux resize-pane -U 20
            tmux resize-pane -R 15
        fi
    done
    tmux attach
}

