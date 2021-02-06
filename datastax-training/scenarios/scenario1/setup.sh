#!/usr/bin/env bash

#
# File: scenario1/setup.sh
# Author: Brendan Cicchi
#
# Created: Sunday, January 31 2021
#

# Return Codes for setup.sh
# 0 - Restart node 0
# 1 - Restart all nodes
# 2 - Do not restart node
# 10 - Error in script

_script_name="$(basename $0)"

function main {
    validate_launch_variables
    initial_setup
    setup_scenario
    exit 0
}

function log {
    DT="$(date -u '+%H:%M:%S')"
    echo "$DT [$_script_name] - $1"
}

function validate_launch_variables {
    if [[ -z $CTOOL || -z $CA || -z $PASSWORD || -z $TMP || -z $CLUSTER_NAME ]]; then
        log "ERROR: Script needs to be executed via run-scenario.sh"
        exit 10
    fi
}

function initial_setup {
    _scenario=$(basename $(dirname $0))
    TMP="$TMP/$_scenario"
    [[ -d $TMP ]] && rm -rf $TMP
    mkdir $TMP
}

function setup_scenario {
    log "Configuring $_scenario..."
    _ctool_info=$(eval "$CTOOL info $CLUSTER_NAME")
    _node_ip=($(echo "$_ctool_info" | grep 'public hostname' | head -n 1 | cut -d ' ' -f3))
    _node_host=($(echo "$_ctool_info" | grep 'private hostname' | head -n 1 | cut -d ' ' -f3))
    _sans="IP:$_node_ip,DNS:$_node_host"
    $CA -i $CLUSTER_NAME -p $PASSWORD -s $_scenario -e $_sans -z $TMP/working_$_scenario &> /dev/null
    tar -xf $TMP/working_$_scenario.tar.gz -C $TMP
    openssl pkcs12 -export \
      -in $TMP/$_scenario.cert.pem \
      -inkey $TMP/$_scenario.key.pem -passin pass:$PASSWORD \
      -out $TMP/$_scenario.p12 -password pass:$PASSWORD
    keytool -importkeystore -srckeystore $TMP/$_scenario.p12 -srcstoretype PKCS12 -srcstorepass $PASSWORD \
      -destkeystore $TMP/$_scenario.jks -deststoretype JKS -deststorepass $PASSWORD &> /dev/null
    tar -czPf $TMP/$_scenario.tar.gz -C $TMP $_scenario.jks datastax-ssl-training-truststore.jks
    eval "$CTOOL scp $CLUSTER_NAME 0 $TMP/$_scenario.tar.gz /home/automaton"
    rm -rf $TMP
    eval "$CTOOL run $CLUSTER_NAME 0 \"\
      [[ ! -d /home/automaton/$CLUSTER_NAME/$_scenario/ ]] && mkdir -p /home/automaton/$CLUSTER_NAME/$_scenario/; \
      tar -xf /home/automaton/$_scenario.tar.gz -C /home/automaton/$CLUSTER_NAME/$_scenario/; \
      chown -R cassandra: /home/automaton/$CLUSTER_NAME/$_scenario/; \
      rm /home/automaton/$_scenario.tar.gz
      \" > /dev/null"
    eval "$CTOOL yaml $CLUSTER_NAME 0 -o set -f cassandra.yaml -k server_encryption_options.keystore \
      -v '\"\/home\/automaton\/$CLUSTER_NAME\/$_scenario\/$_scenario.jks\"' > /dev/null"
    eval "$CTOOL yaml $CLUSTER_NAME 0 -o set -f cassandra.yaml -k server_encryption_options.truststore \
      -v '\"\/home\/automaton\/$CLUSTER_NAME\/$_scenario\/$CLUSTER_NAME-truststore.jks\"' > /dev/null"
    eval "$CTOOL yaml $CLUSTER_NAME 0 -o delete -f cassandra.yaml -k server_encryption_options.cipher_suites > /dev/null"
    log "$_scenario was successfully configured"
}


main "$@"