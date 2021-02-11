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
_script_name="$(basename $0)"
ctool_deploy_certs="$_script_path/../integrations/ctool-deploy-certs.sh"
_scenario_num=
_tear_down_env=
_verbose=

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
    while getopts ":hs:vx" _opt; do
        case $_opt in
            h )
                _print_usage
                exit 0
                ;;
            s )
                _validate_optarg $OPTARG
                _scenario_num="$OPTARG"
                ;;
            v )
                export CA="$CA -v"
                ctool_deploy_certs="$ctool_deploy_certs -v"
                _verbose=true
                ;;
            x )
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
    echo "    -v                        Generate verbose output"
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

function maybe_log() {
    if [[ ! -z $_verbose ]]; then
        log "$1"
    fi
}

function log() {
    DT="$(date -u '+%H:%M:%S')"
    echo "$DT [$_script_name] - $1"
}

function _execute_command() {
    maybe_log "COMMAND: $1"
    eval "$1"
    if [[ $? -ne 0 ]]; then
        log "ERROR: $2"
        exit 1
    fi
}

function setup_cluster()
{
    _cmd="_ctool_list_output=\$($CTOOL list)"
    _execute_command "$_cmd" "Failed to execute ctool list. Please ensure your ctool environment is configured properly"
    if ! echo "$_ctool_list_output" | tail -n +2 | cut -d ',' -f1 | grep -w $CLUSTER_NAME > /dev/null; then
        log "Launching $CLUSTER_NAME in $PROVIDER..."
        _cmd="$CTOOL launch $CLUSTER_NAME 2 -i $INSTANCE_TYPE > /dev/null"
        _execute_command "$_cmd" "Failed to launch $CLUSTER_NAME in $PROVIDER"
        log "Installing DSE $DSE_VERSION..."
        _cmd="$CTOOL install $CLUSTER_NAME enterprise -v $DSE_VERSION-1 -n 8 -z GossipingPropertyFileSnitch > /dev/null"
        _execute_command "$_cmd" "Failed to install DSE $DSE_VERSION on $CLUSTER_NAME"
    else
        log "$CLUSTER_NAME has already been launched on $PROVIDER"
    fi
    _cmd="_ctool_run_ls_output=\$($CTOOL run $CLUSTER_NAME 0 'ls -1')"
    _execute_command "$_cmd" "Failed to check if ctool_deploy_certs had already been run"
    if ! echo "$_ctool_run_ls_output" | grep -w node.tar.gz; then
        log "Performing initial SSL configuration for training..."
        _cmd="$ctool_deploy_certs -aoc $CLUSTER_NAME -t $TMP"
        _execute_command "$_cmd" "Failed to run '$ctool_deploy_certs'"
        log "SSL configuration complete"
    else
        log "Cluster has already been configured for SSL"
    fi
    log "Validating nodes have started..."
    _cmd="_return_codes_output=\$($CTOOL run $CLUSTER_NAME all 'ps -ef | grep DseModule | grep -v grep' | grep 'Return Code:' | cut -d ' ' -f3)"
    _execute_command "$_cmd" "Failed to get the return codes from ps output"
    if echo $_return_codes_output | grep -w "1" > /dev/null; then
        start_node "all"
    fi
}

function execute_scenario()
{
    _launch_path="$_script_path/scenarios/scenario$_scenario_num/setup.sh"
    log "Deploying scenario $_scenario_num via $_launch_path"
    $_script_path/scenarios/scenario$_scenario_num/setup.sh
    case $? in
        0)
            restart_node "0"
            ;;
        1)
            restart_node "all"
            ;;
        10)
            log "ERROR: Failed to execute $_script_path/scenarios/scenario$_scenario_num/setup.sh"
            exit 1
            ;;
        *)
            log "ERROR: unrecognized return code from $_script_path/scenarios/scenario$_scenario_num/setup.sh"
            exit 1
            ;;
    esac
}

function start_node()
{
    [[ $1 -eq "all" ]] && log "Starting DSE nodes ($1)..." || log "Starting DSE node ($1)..."
    _cmd="$CTOOL restart --dont-wait --parallel $CLUSTER_NAME $1 > /dev/null"
    _execute_command "$_cmd" "Failed to start nodes in $CLUSTER_NAME, check the DSE logs for more information"
    log "Start complete"
}

function restart_node()
{
    [[ $1 -eq "all" ]] && log "Restarting DSE nodes ($1)..." || log "Restarting DSE node ($1)..."
    _cmd="$CTOOL restart --dont-wait --parallel $CLUSTER_NAME $1 > /dev/null"
    _execute_command "$_cmd" "Failed to restart nodes in $CLUSTER_NAME, check the DSE logs for more information"
    log "Restart complete"
}

function tear_down_environment()
{
  log "Destroying $PROVIDER instances..."
  _cmd="$CTOOL destroy $CLUSTER_NAME > /dev/null"
  _execute_command "$_cmd" "Failed to destroy $CLUSTER_NAME in $PROVIDER. Please clean up manually."
  log "Cleaning up certificate authority entries..."
  _cmd="$CA -x $CLUSTER_NAME -p $PASSWORD"
  _execute_command "$_cmd" "Failed to revoke $CLUSTER_NAME as an intermediate in the certificate-authority"
  log "Environment has been torn down."
}

main "$@"