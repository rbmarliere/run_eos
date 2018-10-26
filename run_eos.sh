#!/bin/sh

source $(dirname "$0")/prompt_input_yN/prompt_input_yN.sh

eosiocheck()
{
    if [ "${EOSIO_ROOT}"  = "" ] \
    || [ "${EOSIO_CROOT}" = "" ] \
    || [ "${EOSIO_URL}"   = "" ]; then
        printf "error: an environment variable is null, check your eosioconf\n"
        return 1
    fi
    if [ ! -f "${cleos}" ] \
    || [ ! -f "${nodeos}" ]; then
        printf "error: a binary was not found in ${EOSIO_ROOT}, check your eosioconf\n"
        return 1
    fi
}

eosioconf()
{
    if [ $# -lt 3 ]; then
        printf "usage: eosioconf eosio_root chain_root api_url\n"
        printf "e.g. eosioconf /usr/local ~/eos_localnet http://127.0.0.1:8888\n\n"
        printf "eosio_root: ${EOSIO_ROOT}\n"
        printf "chain_root: ${EOSIO_CROOT}\n"
        printf "api_url: ${EOSIO_URL}\n"
        return 1
    fi

    export EOSIO_ROOT=$1  ; shift
    export EOSIO_CROOT=$1 ; shift
    export EOSIO_URL=$1   ; shift

    export cleos=$(find ${EOSIO_ROOT} -type f -iname cleos)
    export eosiocpp=$(find ${EOSIO_ROOT} -type f -iname eosio-cpp)
    export eosioabi=$(find ${EOSIO_ROOT} -type f -iname eosio-abigen)
    export nodeos=$(find ${EOSIO_ROOT} -type f -iname nodeos)
}

eosiocpp()
{
    eosiocheck || return 1
    ${eosiocpp} $@
}

eosioabi()
{
    eosiocheck || return 1
    ${eosioabi} $@
}

cleos()
{
    eosiocheck || return 1
    ${cleos} \
        --url ${EOSIO_URL} \
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
        else
            rm -f ${EOSIO_CROOT}/data/pid
        fi
    fi

    if [ -d ${EOSIO_CROOT}/data/blocks ]; then
        prompt_input_yN "clean blocks" && rm -rf ${EOSIO_CROOT}/data/blocks
    fi
    if prompt_input_yN "replay"; then
        REPLAY=--replay
        prompt_input_yN "hard-replay" && HREPLAY=--hard-replay || HREPLAY=
    else
        REPLAY=
        HREPLAY=
    fi
    [ -f ${EOSIO_CROOT}/data/blocks/blocks.log ] && GENESIS= || GENESIS=--genesis-json="${EOSIO_CROOT}/config/genesis.json"
    DATE=$(date +'%Y_%m_%d_%H_%M_%S')

    nohup ${nodeos} \
        --data-dir="${EOSIO_CROOT}/data" \
        --config="${EOSIO_CROOT}/config/config.ini" \
        ${GENESIS} \
        ${REPLAY} \
        ${HREPLAY} \
        $@ \
        < /dev/null \
        2>&1 \
        > ${EOSIO_CROOT}/log/${DATE}.log \
        &

    [ -L ${EOSIO_CROOT}/log/lastlog ] && unlink ${EOSIO_CROOT}/log/lastlog
    ln -s ${EOSIO_CROOT}/log/${DATE}.log ${EOSIO_CROOT}/log/lastlog

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

