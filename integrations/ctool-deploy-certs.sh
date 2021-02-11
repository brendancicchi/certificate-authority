#!/usr/bin/env bash

#
# File: ctool-deploy-certs.sh
# Author: Brendan Cicchi
#
# Created: Tuesday, July 2 2019
#

##### Begin Configurations #####
[[ -z $PROVIDER ]] && PROVIDER="nebula"
[[ -z $CTOOL ]] && CTOOL="PYENV_VERSION=2.7.17/envs/ctool ctool --provider=${PROVIDER}"
[[ -z $PASSWORD ]] && PASSWORD="cassandra"
##### End Configurations #####

[[ -z $CA ]] && CA="$(dirname $0)/../certificate-authority.sh"
_script_name="$(basename $0)"

function main()
{
  parse_arguments "$@"
  _ctool_info=$(eval "$CTOOL info $_cluster_name")
  if [ -z "$_ctool_info" ]; then
    echo "ERROR :: $_cluster_name not found by CTOOL"
    exit 1
  fi
  _node_ips_array=($(echo "$_ctool_info" | grep 'public hostname' | cut -d ' ' -f3))
  _node_hosts_array=($(echo "$_ctool_info" | grep 'private hostname' | cut -d ' ' -f3))
  
  _generate_dse_certificates
  _configure_dse_nodes
  _configure_cqlsh
  _optional_restart_dse
}

function parse_arguments()
{
    if [ $# -lt 1 ]; then
        echo -e "No arguments were passed\n"
        _print_usage
    fi
    # Clear variables just in case
    _require_client_auth=false
    _cluster_name=
    _optional_ssl=false
    _restart_nodes=
    _tmp_dir="/tmp"
    _verbose=
    while getopts ":ac:hort:v" _opt; do
      case $_opt in
        a )
          _require_client_auth=true
          ;;
        c )
          _validate_optarg $OPTARG
          _cluster_name="$OPTARG"
          ;;
        h )
          _print_usage
          exit 0
          ;;
        o )
          _optional_ssl=true
          ;;   
        r)
          _restart_nodes=true
          ;;
        t)
          _validate_optarg $OPTARG
          _tmp_dir="$OPTARG"
          ;;
        v)
          CA="$CA -v"
          _verbose=true
          ;;
        \?)
          echo -e "Invalid option: -$OPTARG\n"
          _print_usage
          exit 1
          ;;
        :)
          echo -e "Option -$OPTARG requires an argument.\n"
          _print_usage
          exit 1
        ;;
        esac
    done
  if [ -z $_cluster_name ]; then
    echo "ERROR :: No cluster name provided via -c"
    exit 1
  fi
}

function _validate_optarg
{
    if [[ $1 == -* ]];then
        echo -e "Missing an argument\n"
        exit 1
    fi
}

function _print_usage()
{
    echo "Usage:"
    echo "-> Mandatory Arguments:"
    echo "    -c                       CTOOL cluster name"
    echo "-> Optional Arguments:"    
    echo "    -a                       Use mutual authentication (2-way SSL) for clients"
    echo "    -h                       Display this help message."
    echo "    -o                       Allow optional client connections"
    echo "    -r                       Restart the nodes in parallel"
    echo "    -t <tmp_dir>             Directory to store temporary files (Default: /tmp)"
    echo "    -v                       Generate verbose output"
}

function maybe_log() {
    if [[ ! -z $_verbose ]]; then
        log "$1"
    fi
}

function log {
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

function _generate_dse_certificates()
{
  log "Generating certificates for DSE nodes..."
  for ((i=0;i<${#_node_ips_array[@]};++i)); do
    _cn="node"$i
    _sans="IP:${_node_ips_array[i]},DNS:${_node_hosts_array[i]}"
    [[ -f $_tmp_dir/$_cluster_name-$_cn.tar.gz ]] && rm $_tmp_dir/$_cluster_name-$_cn.tar.gz
    _cmd="$CA -r -i $_cluster_name -s $_cn -e $_sans -z $_tmp_dir/$_cluster_name-$_cn -p $PASSWORD"
    _execute_command "$_cmd" "Failed to generate certificates for $_cn"
    _cmd="$CTOOL scp $_cluster_name $i $_tmp_dir/$_cluster_name-$_cn.tar.gz /home/automaton/node.tar.gz > /dev/null"
    _execute_command "$_cmd" "Failed to scp $_tmp_dir/$_cluster_name-$_cn.tar.gz to $_cluster_name (node$i)"
    rm $_tmp_dir/$_cluster_name-$_cn.tar.gz
  done
}

function _generate_cqlsh_certificates()
{
  log "Generating certificates for CQLSH clients..."
  for ((i=0;i<${#_node_ips_array[@]};++i)); do
    _cn="cqlsh"$i
    _sans="IP:${_node_ips_array[i]},DNS:${_node_hosts_array[i]}"
    [[ -f $_tmp_dir/$_cluster_name-$_cn.tar.gz ]] && rm $_tmp_dir/$_cluster_name-$_cn.tar.gz
    _cmd="$CA -r -i $_cluster_name -c $_cn -e $_sans -z $_tmp_dir/$_cluster_name-$_cn -p $PASSWORD"
    _execute_command "$_cmd" "Failed to generate certificates for the CQLSH client on node$i"
    _cmd="$CTOOL scp $_cluster_name $i $_tmp_dir/$_cluster_name-$_cn.tar.gz /home/automaton/cqlsh.tar.gz"
    _execute_command "$_cmd" "Failed to scp $_tmp_dir/$_cluster_name-$_cn.tar.gz to $_cluster_name (node$i)"
    rm $_tmp_dir/$_cluster_name-$_cn.tar.gz
  done
}

function _configure_dse_nodes()
{
  log "Configuring client_encryption_options..."
  _cmd="$CTOOL run $_cluster_name all 'sudo mkdir -p /etc/dse/security/ && \
    sudo tar -xf /home/automaton/node.tar.gz -C /etc/dse/security/ && \
    [[ ! -e /etc/dse/security/node-keystore.jks ]] && sudo ln -s /etc/dse/security/*-keystore.jks /etc/dse/security/node-keystore.jks && \
    [[ ! -e /etc/dse/security/node-keystore.pfx ]] && sudo ln -s /etc/dse/security/*-keystore.pfx /etc/dse/security/node-keystore.pfx && \    
    sudo chown -R cassandra:cassandra /etc/dse/security/' \
    > /dev/null"
  _execute_command "$_cmd" "Failed to extract DSE certificates in $_cluster_name"

  # Configure client_encryption_options
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k client_encryption_options.enabled -v '\"true\"' $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to enable client_encryption_options in $_cluster_name"
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k client_encryption_options.keystore -v '\"\/etc\/dse\/security\/node-keystore.jks\"' $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to set keystore location for client_encryption_options in $_cluster_name"
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k client_encryption_options.keystore_password -v '\"$PASSWORD\"' $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to set keystore password for client_encryption_options in $_cluster_name"
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k client_encryption_options.truststore -v '\"\/etc\/dse\/security\/$_cluster_name-truststore.jks\"' $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to set truststore location for client_encryption_options in $_cluster_name"
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k client_encryption_options.truststore_password -v '\"$PASSWORD\"' $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to set truststore password for client_encryption_options in $_cluster_name"
  _cmd="$CTOOL yaml -o delete -f cassandra.yaml -k client_encryption_options.cipher_suites $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to clear cipher_suites for client_encryption_options in $_cluster_name"
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k client_encryption_options.optional -v $_optional_ssl $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to set optional to $_optional_ssl for client_encryption_options in $_cluster_name"
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k client_encryption_options.require_client_auth -v $_require_client_auth $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to set require_client_auth to $_require_client_auth for client_encryption_options in $_cluster_name"

  # Configure server_encryption_options
  log "Configuring server_encryption_options..."
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k server_encryption_options.internode_encryption -v '\"all\"' $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to set server_encryption_options to all in $_cluster_name"
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k server_encryption_options.keystore -v '\"\/etc\/dse\/security\/node-keystore.jks\"' $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to set keystore location for server_encryption_options in $_cluster_name"
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k server_encryption_options.keystore_password -v '\"$PASSWORD\"' $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to set keystore password for server_encryption_options in $_cluster_name"
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k server_encryption_options.truststore -v '\"\/etc\/dse\/security\/$_cluster_name-truststore.jks\"' $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to set truststore location for server_encryption_options in $_cluster_name"
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k server_encryption_options.truststore_password -v '\"$PASSWORD\"' $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to set truststore password for server_encryption_options in $_cluster_name"
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k server_encryption_options.require_endpoint_verification -v true $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to enable endpoint verification for server_encryption_options in $_cluster_name"
  _cmd="$CTOOL yaml -o set -f cassandra.yaml -k server_encryption_options.require_client_auth -v true $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to enable 2-way SSL for server_encryption_options in $_cluster_name"
  _cmd="$CTOOL yaml -o delete -f cassandra.yaml -k server_encryption_options.cipher_suites $_cluster_name > /dev/null"
  _execute_command "$_cmd" "Failed to clear cipher suites for server_encryption_options in $_cluster_name"
}

function _configure_cqlsh()
{
  log "Configuring cqlshrc for automaton..."
  _cqlshrc="[ssl]\nvalidate = true\ncertfile=/etc/dse/security/ca.cert.pem"
  if [ ! -z $_require_client_auth ]; then
    _generate_cqlsh_certificates
    _cmd="$CTOOL run $_cluster_name all \"mkdir -p /home/automaton/.cassandra/certs/ && \
    tar -xf /home/automaton/cqlsh.tar.gz -C /home/automaton/.cassandra/certs/ && \
    openssl rsa -in /home/automaton/.cassandra/certs/cqlsh*.key.pem -passin pass:$PASSWORD -out /home/automaton/.cassandra/certs/cqlsh.key && \
    chmod 600 /home/automaton/.cassandra/certs/cqlsh.key && \
    cat /home/automaton/.cassandra/certs/cqlsh*.cert.pem /home/automaton/.cassandra/certs/$_cluster_name.cert.pem >| /home/automaton/.cassandra/certs/cqlsh.chain.pem\" \
    > /dev/null"
    _execute_command "$_cmd" "Failed to extract CQLSH certificates in $_cluster_name"
    _cqlshrc=$(echo -e "$_cqlshrc\nuserkey=/home/automaton/.cassandra/certs/cqlsh.key\nusercert=/home/automaton/.cassandra/certs/cqlsh.chain.pem")
  fi

  _cmd="$CTOOL run $_cluster_name all 'mkdir -p /home/automaton/.cassandra/ && \
    echo -e \"$_cqlshrc\" >| /home/automaton/.cassandra/cqlshrc && \
    sudo chmod 600 /home/automaton/.cassandra/cqlshrc && \
    sudo mkdir -p /root/.cassandra && \
    sudo cp /home/automaton/.cassandra/cqlshrc /root/.cassandra/ && \
    sudo chown -R root:root /root/.cassandra && \
    sudo chmod 600 /root/.cassandra/cqlshrc' \
    > /dev/null"
  _execute_command "$_cmd" "Failed to create cqlshrc in $_cluster_name"
}

function _optional_restart_dse()
{

  if [ ! -z $_restart_nodes ]; then
    log "Restarting DSE nodes in parallel..."
    _cmd="$CTOOL restart -p $_cluster_name > /dev/null"
    _execute_command "$_cmd" "Failed to restart $_cluster_name"
  fi
}


main "$@"
