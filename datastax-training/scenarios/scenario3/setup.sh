#!/usr/bin/env bash

#
# File: scenario3/setup.sh
# Author: Brendan Cicchi
#
# Created: Friday, February 5 2021
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
    $CA -i $CLUSTER_NAME -p $PASSWORD -s $_scenario -z $TMP/$_scenario
    eval "$CTOOL scp $CLUSTER_NAME 0 $TMP/$_scenario.tar.gz /home/automaton/"
    rm -rf $TMP
    eval "$CTOOL run $CLUSTER_NAME 0 \"\
      [[ ! -d /home/automaton/$CLUSTER_NAME/$_scenario/ ]] && mkdir -p /home/automaton/$CLUSTER_NAME/$_scenario/; \
      sudo chown -R automaton:automaton /home/automaton/$CLUSTER_NAME/; \
      tar -xf /home/automaton/$_scenario.tar.gz -C /home/automaton/$CLUSTER_NAME/$_scenario/; \
      sudo chown -R cassandra:cassandra /home/automaton/$CLUSTER_NAME/$_scenario/; \
      rm /home/automaton/$_scenario.tar.gz \
      \" > /dev/null"
    eval "$CTOOL yaml $CLUSTER_NAME 0 -o set -f cassandra.yaml -k server_encryption_options.keystore \
      -v '\"\/home\/automaton\/$CLUSTER_NAME\/$_scenario\/$_scenario-keystore.jks\"' > /dev/null"
    eval "$CTOOL yaml $CLUSTER_NAME 0 -o set -f cassandra.yaml -k server_encryption_options.truststore \
      -v '\"\/home\/automaton\/$CLUSTER_NAME\/$_scenario\/$CLUSTER_NAME-truststore.jks\"' > /dev/null"
    eval "$CTOOL yaml $CLUSTER_NAME 0 -o delete -f cassandra.yaml -k server_encryption_options.cipher_suites > /dev/null"
    log "$_scenario was successfully configured"
}


main "$@"