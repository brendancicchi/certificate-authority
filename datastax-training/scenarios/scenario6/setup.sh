#!/usr/bin/env bash

#
# File: scenario4/setup.sh
# Author: Brendan Cicchi
#
# Created: Friday, February 19 2021
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
    keytool -genkeypair -alias 1 -keystore $TMP/$_scenario-keystore.jks -ext SAN=$_sans -storepass cassandra \
      -keypass cassandra -dname "CN=node0, OU=Support, O=DataStax, ST=CA, C=US" 2> /dev/null
    eval "$CTOOL scp $CLUSTER_NAME 0 $TMP/$_scenario-keystore.jks /home/automaton/"
    rm -rf $TMP
    eval "$CTOOL run $CLUSTER_NAME 0 \"\
      [[ ! -d /home/automaton/$CLUSTER_NAME/$_scenario/ ]] && mkdir -p /home/automaton/$CLUSTER_NAME/$_scenario/; \
      sudo chown -R automaton:automaton /home/automaton/$CLUSTER_NAME/; \
      mv /home/automaton/$_scenario-keystore.jks /home/automaton/$CLUSTER_NAME/$_scenario/; \
      cp /etc/dse/security/datastax-ssl-training-truststore.jks /home/automaton/$CLUSTER_NAME/$_scenario/; \
      cd /home/automaton/$CLUSTER_NAME/$_scenario/; \
      sudo chown -R cassandra:cassandra /home/automaton/$CLUSTER_NAME/$_scenario/; \
      \" > /dev/null"

    eval "$CTOOL yaml $CLUSTER_NAME 0 -o set -f cassandra.yaml -k server_encryption_options.keystore \
      -v '\"\/home\/automaton\/$CLUSTER_NAME\/$_scenario\/$_scenario-keystore.jks\"' > /dev/null"
    eval "$CTOOL yaml $CLUSTER_NAME 0 -o set -f cassandra.yaml -k server_encryption_options.truststore \
      -v '\"\/home\/automaton\/$CLUSTER_NAME\/$_scenario\/$CLUSTER_NAME-truststore.jks\"' > /dev/null"
    eval "$CTOOL yaml $CLUSTER_NAME 0 -o delete -f cassandra.yaml -k server_encryption_options.cipher_suites > /dev/null"
    log "$_scenario was successfully configured"
}


main "$@"