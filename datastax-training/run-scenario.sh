#!/usr/bin/env bash

#
# File: run-scenario.sh
# Author: Brendan Cicchi
#
# Created: Sunday, January 31 2021
#

##### Begin Configurations #####
export PROVIDER="nebula"
export CTOOL="PYENV_VERSION=2.7.17/envs/ctool ctool --provider=${PROVIDER}"
export PASSWORD="cassandra"
export TMP="/tmp"
export CLUSTER_NAME="datastax-ssl-training"
INSTANCE_TYPE="c4.large"
DSE_VERSION="6.8.9"
##### End Configurations #####

export CA="$(dirname $(echo "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")"))/../certificate-authority.sh" # https://stackoverflow.com/a/3915420/10156762
_script_path="$(dirname $0)"
_cassandra_yaml_path="/etc/dse/cassandra/cassandra.yaml"
_scenario_num=
_tear_down_env=

function main()
{
    parse_arguments "$@"
    if ! validate_arguments; then
        _print_usage
        exit 1
    fi
    if [[ ! -z $_tear_down_env ]]; then
        tear_down_environment
        exit 0
    fi
    setup_cluster
    execute_scenario
    log "Scenario $_scenario_num is good to go. Knock yourself out."
    exit 0
}

function parse_arguments()
{
    while getopts ":hs:x" _opt; do
        case $_opt in
            h )
                _print_usage
                exit 0
                ;;
            s )
                _validate_optarg $OPTARG
                _scenario_num="$OPTARG"
                ;;
            x )
                _validate_optarg $OPTARG
                _tear_down_env="true"
                ;;
            \?)
                log "ERROR: Invalid option: -$OPTARG"
                _print_usage
                exit 1
                ;;
            :)
                log "ERROR: Option -$OPTARG requires an argument."
                _print_usage
                exit 1
                ;;
        esac
    done
}

function _print_usage()
{
    echo "Usage:"
    echo "    -h                        Display this help message."
    echo "    -s <number>               Scenario to run"
    echo "    -x                        Destroy training environment"
}

function _validate_optarg()
{
    if [[ $1 == -* ]]; then
        log "ERROR: Missing an argument"
        exit 1
    fi
}

function validate_arguments()
{
    if [[ -z $_scenario_num && -z $_tear_down_env ]]; then
        log "ERROR: Either a scenario (-s) or cleanup (-x) must be executed"
        return 1
    fi
    if [[ ! -z $_scenario_num && ! -z $_tear_down_env ]]; then
        log "ERROR: A scenario and cleanup cannot both be executed"
        return 1
    fi
    if [[ ! -z $_scenario_num ]]; then
        _scenario_nums=$(ls -1 $_script_path/scenarios/ | grep -Eo '[0-9]+$')
        if ! echo "$_scenario_nums" | grep -w $_scenario_num > /dev/null; then
            log "ERROR: An invalid scenario was attempted: $_scenario_num"
            return 1
        fi
    fi
}

function log {
    DT="$(date -u '+%H:%M:%S')"
    echo "[$DT] - $1"
}

function setup_cluster()
{
    if ! eval "$CTOOL list | tail -n +2 | cut -d ',' -f1 | grep -w $CLUSTER_NAME > /dev/null"; then
        log "Launching $CLUSTER_NAME in $PROVIDER..."
        eval "$CTOOL launch $CLUSTER_NAME 2 -i $INSTANCE_TYPE > /dev/null"
        log "Installing DSE $DSE_VERSION..."
        eval "$CTOOL install $CLUSTER_NAME enterprise -v $DSE_VERSION-1 -n 8 -z GossipingPropertyFileSnitch > /dev/null"
    else
        log "$CLUSTER_NAME has already been launched on $PROVIDER"
    fi
    if ! eval "$CTOOL run $CLUSTER_NAME 0 'ls -1 | grep -w node.tar.gz' > /dev/null"; then
        log "Performing initial SSL configuration for training..."
        $_script_path/../integrations/ctool-deploy-certs.sh -aoc $CLUSTER_NAME -t $TMP
        log "SSL configuration complete"
    else
        log "Cluster has already been configured for SSL"
    fi
    log "Validating nodes have started..."
    if ! eval "$CTOOL start $CLUSTER_NAME > /dev/null"; then
        log "ERROR: Nodes failed to start. Nodes must be either be up or able to be started prior to launching a scenario."
        exit 1
    else
        log "Nodes successfully started"
    fi
}

function execute_scenario()
{
    _launch_path="$_script_path/scenarios/scenario$_scenario_num/setup.sh"
    log "Deploying scenario $_scenario_num via $_launch_path"
    $_script_path/scenarios/scenario$_scenario_num/setup.sh
    _exit_code=$?
    [[ $_exit_code -eq 0 ]] && restart_node "0"
    [[ $_exit_code -eq 1 ]] && restart_node "all"
    [[ $_exit_code -eq 10 ]] && log "Failed to execute $_script_path/scenarios/scenario$_scenario_num/setup.sh"
}

function restart_node()
{
    [[ $1 -eq "all" ]] && log "Restarting DSE nodes ($1)..." || log "Restarting DSE node ($1)..."
    eval "$CTOOL restart --dont-wait --parallel $CLUSTER_NAME $1 > /dev/null"
    log "Restart complete"
}

function tear_down_environment()
{
  log "Destroying $PROVIDER instances..."
  eval "$CTOOL destroy $CLUSTER_NAME > /dev/null"
  log "Cleaning up certificate authority entries..."
  $CA -x $CLUSTER_NAME -p $PASSWORD &> /dev/null
  log "Environment has been torn down."
}

main "$@"