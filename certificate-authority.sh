#!/usr/bin/env bash

#
# File: certificate-authority.sh
# Author: Brendan Cicchi
#
# Created: Tuesday, July 2 2019
#

function main()
{
    source $(dirname ${BASH_SOURCE[0]})/conf/ssl-var-configuration.sh   
    parse_arguments "$@"
    if ! validate_arguments; then
        _print_usage
        exit 1
    fi

    [[ ! -z $_store_intermediate_name ]] && source_intermediate_vars $_store_intermediate_name

    if [[ ! -z $_flag_list_certs ]]; then
        [[ ! -z $_store_intermediate_name ]] && print_leaves || print_intermediates
        exit 0
    fi
    if [[ ! -z $_store_revoke_name ]]; then
        if [[ ! -z $_store_intermediate_name ]]; then
            source_leaf_vars $_store_revoke_name $_intermediate_dir
            revoke_leaf
        else
            source_intermediate_vars $_store_revoke_name
            revoke_intermediate
        fi
        exit 0
    fi
    if [[ ! -z $_flag_rootca ]]; then
        create_rootca
    fi
    if [[ ! -z $_store_intermediate_name ]]; then
        create_intermediate
        create_truststores $_store_intermediate_name
    fi
    if [[ ! -z $_leaf_certificate_type ]]; then
        source_leaf_vars $_store_leaf_certificate_name $_intermediate_dir
        create_leaf
        create_keystores
    fi
    [[ ! -z $_store_zip_name ]] && zip_certificates
    exit 0
}

function parse_arguments()
{
    if [ $# -lt 1 ]; then
        echo -e "No arguments were passed\n"
        _print_usage
    fi
    while getopts ":c:e:hi:lp:rs:t:vx:z:" _opt; do
        case $_opt in
            c)
                _validate_optarg $OPTARG
                _store_leaf_certificate_name="$OPTARG"
                _leaf_certificate_type="usr_cert"
                _flag_client_certificate=true
                ;;
            e)
                _validate_optarg $OPTARG
                _store_san_extensions="$OPTARG"
                ;;
            h )
                _print_usage
                exit 0
                ;;
            i)
                _validate_optarg $OPTARG
                _store_intermediate_name="$OPTARG"
                ;;
            l )
                _flag_list_certs=true
                ;;
            p)
                _validate_optarg $OPTARG
                _store_password="$OPTARG"
                ;;
            r)
                _flag_rootca=true
                ;;
            s)
                _validate_optarg $OPTARG
                _store_leaf_certificate_name="$OPTARG"
                _leaf_certificate_type="server_cert"
                _flag_server_certificate=true
                ;;
            t)
                _validate_optarg $OPTARG
                _time_to_live="$OPTARG"
                ;;
            v)
                _verbose=true
                ;;
            x)
                _validate_optarg $OPTARG
                _store_revoke_name="$OPTARG"
                ;;
            z)
                _validate_optarg $OPTARG
                _store_zip_name="$OPTARG.tar"
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
}

function _print_usage()
{
    echo "Usage:"
    echo "    -c <client_cert_name>    Create a client certificate with given name"
    echo "                               - Requires -i <intermediate_name> to sign"
    echo "    -e <IP:ip,DNS:host,...>  SAN list to be used for server or client certificate"
    echo "                               - Requires -s <server_cert_name> or -c <client_cert_name>"
    echo "    -h                       Display this help message."
    echo "    -i <intermediate_name>   Create or use intermediate with given name"
    echo "                               - The name should be the same as the CN"
    echo "    -l                       List created intermediates"
    echo "                               - Use with -i <intermediate> to show leaf certificates"
    echo "    -p <password>            Password to be applied to ALL openssl and keytool commands"
    echo "                               - This is not secure and only meant for dev environment purposes"
    echo "                               - Removes all prompting from the user"
    echo "    -r                       Create the rootca key and certificate"
    echo "    -s <server_cert_name>    Create a server certificate with given name"
    echo "                               - Requires -i <intermediate_name> to sign"
    echo "    -t <seconds>             TTL to provide to any certificate created (Unit: seconds)"
    echo "    -v                       Generate verbose output"
    echo "    -x <certificate_name>    Revoke the named certificate"
    echo "                               - Use with -i <intermediate> to specify a leaf certificate"
    echo "                               - Otherwise assumes intermediate certificate"
    echo "    -z <zip_name>            Zip up the relevant certificates, keys, and stores"
    echo "                               - Use with -i <intermediate> to only zip the public chain and stores"
    echo "                               - Use with -c or -s to include the keys and keystores"
}

function _validate_optarg()
{
    if [[ $1 == -* ]];then
        echo -e "Missing an argument for $_opt\n"
        exit 1
    fi
}

function validate_arguments()
{
    if [[ ! -z $_flag_server_certificate && ! -z $_flag_client_certificate ]]; then
        echo -e "Option -c and -s cannot both be supplied.\n"
        return 1
    elif [[ ! -z $_leaf_certificate_type && -z $_store_intermediate_name ]]; then
        echo -e "An intermediate must be passed with -i to sign the certificate.\n"
        return 1
    elif [[ ! -z $_store_san_extensions && -z $_leaf_certificate_type ]]; then
        echo -e "Option -e can only be used with -c or -s.\n"
        return 1
    elif [[ ! -z $_store_zip_name && -z $_store_intermediate_name ]]; then
        echo -e "An intermediate must be specified with -i <intermediate_name>.\n"
        return 1
    elif [[ $_store_intermediate_name == *\.* ]];then
        echo -e "Intermediate name cannot contain a period (.)\n"
        return 1
    fi
    if [[ ! -z $_time_to_live ]]; then
        if [[ ! $_time_to_live =~ ^[0-9]+$ ]]; then
            echo -e "Seconds provided via -t must be whole numbers.\n"
            return 1
        fi
        _os=$($_os_info)
        _epoch_end_of_life=$(( $(date +%s) + $_time_to_live ))
        if [[ $_os -eq "Mac" ]]; then
            _time_to_live=$(TZ=GMT date -r $_epoch_end_of_life '+%Y%m%d%H%M%SZ')
        elif [[ $_os -eq "Linux" ]]; then
            _time_to_live=$(TZ=GMT date -d@$_epoch_end_of_life '+%Y%m%d%H%M%SZ')
        else
            echo "$_os is an supported OS type for certificate_authority, -t functionality is unavailable."
            return 1
        fi
    fi
    return 0
}

function maybe_log()
{
    if [[ ! -z $_verbose ]]; then
        log "$1"
    fi
}

function log()
{
    DT="$(date -u '+%H:%M:%S')"
    echo "$DT [$_script_name] - $1"
}

function _execute_command()
{
    maybe_log "COMMAND: $1"
    eval "$1"
    if [[ $? -ne 0 ]]; then
        log "ERROR: $2"
        exit 1
    fi
}

function _os_info()
{
    local unameOut="$(uname -s)"
    case "${unameOut}" in
        Linux*)     machine=Linux;;
        Darwin*)    machine=Mac;;
        CYGWIN*)    machine=Cygwin;;
        MINGW*)     machine=MinGw;;
        *)          machine="UNKNOWN:${unameOut}"
    esac
    echo ${machine}
}

function print_intermediates()
{
    if [[ -f $_root_index_file ]]; then
        local _current_intermediates=$(egrep "^V" $_root_index_file \
            | awk '{print $NF}' \
            | awk -F "/" '{s=$NF;for(i=NF-1;i>=1;i--)s=s "," $i; print "\t",s}')
    fi
    [[ ! -z $_current_intermediates ]] \
        && echo -e "All current intermediates:\n$_current_intermediates" \
        || echo -e "No intermediates have been generated"
}

function print_leaves()
{
    if [[ -f $_intermediate_index_file ]]; then
        local _current_leaves=$(egrep "^V" $_intermediate_index_file \
            | awk '{print $NF}' \
            | awk -F "/" '{s=$NF;for(i=NF-1;i>=1;i--)s=s "," $i; print "\t",s}')
    fi
    [[ ! -z $_current_leaves ]] \
        && echo -e "All current leaf certificates for intermediate $_store_intermediate_name:\n$_current_leaves" \
        || echo -e "No leaf certificates have been generated for $_store_intermediate_name"
}

function revoke_intermediate()
{
    if [[ -f $_root_index_file ]]; then
        local _intermediate_id=$(egrep "^V" $_root_index_file \
            | grep "$_store_revoke_name" | cut -f4)
        if [[ ! -z $_intermediate_id ]]; then
            local _cert_to_revoke="${_root_new_certs_dir}/${_intermediate_id}.pem"
            if [[ -z $_store_password ]]; then
                stty -echo
                printf "Enter password for $(basename $_file): "
                read _password
                stty echo
                printf "\n" 
            else
                _password=$_store_password
            fi
            local _openssl_pass_arg="-passin pass:$_password"
            _cmd="openssl ca -revoke $_cert_to_revoke -config $ROOTCA_CNF_FILE $_openssl_pass_arg 2>/dev/null"
            _execute_command "$_cmd" "Failed to revoke $_cert_to_revoke using $ROOTCA_CNF_FILE"
        else
            log "There is no intermediate certificate $_store_revoke_name to be revoked."
        fi
    fi
    _cleanup_intermediate_files
}

function _cleanup_intermediate_files()
{
    [[ -d $_intermediate_dir ]] && rm -rf $_intermediate_dir
    [[ -f $_pkcs12_truststore ]] && rm $_pkcs12_truststore
    [[ -f $_jks_truststore ]] && rm $_jks_truststore
}

function revoke_leaf()
{
    if [[ -f $_intermediate_index_file ]]; then
        local _leaf_id=$(egrep "^V" $_intermediate_index_file \
            | grep "$_store_revoke_name" | cut -f4)
        if [[ ! -z $_leaf_id ]]; then
            local _cert_to_revoke="${_intermediate_new_certs_dir}/${_leaf_id}.pem"
            if [[ -z $_store_password ]]; then
                stty -echo
                printf "Enter password for $(basename $_file): "
                read _password
                stty echo
                printf "\n" 
            else
                _password=$_store_password
            fi
            local _openssl_pass_arg="-passin pass:$_password"

            _cmd="openssl ca -revoke $_cert_to_revoke -config $INTERMEDIATE_CNF_FILE $_openssl_pass_arg 2>/dev/null"
            _execute_command "$_cmd" "Failed to revoke $_cert_to_revoke using $INTERMEDIATE_CNF_FILE"
        else
            log "There is no leaf certificate $_store_revoke_name to be revoked."
        fi
    else
        log "There is no intermediate named $_store_intermediate_name."
    fi
    _cleanup_leaf_files  
}

function _cleanup_leaf_files()
{
    [[ -d $_leaf_dir ]] && rm -rf $_leaf_dir
    [[ -f $_pkcs12_keystore ]] && rm -f $_pkcs12_keystore
    [[ -f $_jks_keystore ]] && rm -f $_jks_keystore
}

function create_rootca()
{
    _prepare_rootca_dirs

    [[ ! -f $_root_private_key ]] && _generate_key $_root_private_key
    [[ ! -f $_root_public_cert ]] && _generate_rootca_cert
}

function _prepare_rootca_dirs()
{
    _create_directories "$_root_dirs_list"
    chmod 700 $_root_private_key_dir
    if [[ ! -f $_root_index_file ]]; then
        touch $_root_index_file
        echo -e "unique_subject = yes" > ${_root_index_file}.attr
    fi
    [[ ! -f $_root_serial_file ]] && echo 1000 > $_root_serial_file
}

function _create_directories()
{
    for _dir in $1
    do
        [[ ! -d $_dir ]] && mkdir -p $_dir
    done
}

function _generate_key()
{
    local _file=$1
    maybe_log "Creating private key: $_file"

    if [[ -z $_store_password ]]; then
        stty -echo
        printf "Enter password for $(basename $_file): "
        read _password
        stty echo
        printf "\n" 
    else
        _password=$_store_password
    fi
    local _openssl_pass_arg="-passout pass:$_password"
    
    local _cmd="openssl genrsa -aes256 -out $_file $_openssl_pass_arg 4096 2>/dev/null"
    _execute_command "$_cmd" "Failed to generate private key $_file"
    chmod 400 $_file
}

function _generate_rootca_cert()
{
    maybe_log "Creating public certificate - $_root_public_cert"
    maybe_log "Using cnf file: $ROOTCA_CNF_FILE"
    maybe_log "Using extension: $_root_extension"

    if [[ -z $_store_password ]]; then
        stty -echo
        printf "Enter password for $_root_private_key: "
        read _password
        stty echo
        printf "\n" 
    else
        _password=$_store_password
    fi
    local _openssl_pass_arg="-batch -passin pass:$_password"

    if [[ -z $_time_to_live ]]; then
      _ttl="-days $_root_days_to_live"
    else
      _ttl="-enddate $_time_to_live"
    fi
    maybe_log "Using TTL: $_ttl"

    _cmd="openssl req -config $ROOTCA_CNF_FILE -key $_root_private_key \
        -new -x509 -days $_root_days_to_live -sha512 -extensions $_root_extension \
        -out $_root_public_cert $_openssl_pass_arg"
    _execute_command "$_cmd" "Failed to generate public certificate for $_root_public_cert"
    chmod 644 $_root_public_cert
}

function create_intermediate()
{
    _prepare_intermediate_dirs

    [[ ! -f $_intermediate_private_key ]] && _generate_key $_intermediate_private_key
    [[ ! -f $_intermediate_csr_file ]] && _generate_intermediate_csr
    [[ ! -f $_intermediate_signed_cert ]] && _sign_intermediate_csr
}

function _prepare_intermediate_dirs()
{
    _create_directories "$_intermediate_dirs_list"
    chmod 700 $_intermediate_private_key_dir
    if [[ ! -f $_intermediate_index_file ]]; then
        touch $_intermediate_index_file
        echo -e "unique_subject = yes" > ${_intermediate_index_file}.attr
    fi
    [[ ! -f $_intermediate_serial_file ]] && echo 1000 > $_intermediate_serial_file
    [[ ! -f $_intermediate_crlnumber ]] && echo 1000 > $_intermediate_crlnumber
}

function _generate_intermediate_csr()
{
    maybe_log "Creating CSR $_intermediate_csr_file..."
    maybe_log "Using cnf file: $INTERMEDIATE_CNF_FILE"

    if [[ -z $_store_password ]]; then
        stty -echo
        printf "Enter password for $_intermediate_private_key: "
        read _password
        stty echo
        printf "\n" 
    else
        _password=$_store_password
    fi
    local _openssl_pass_arg="-batch -passin pass:$_password"
    sed -i.orig -e "s,\(^commonName_default *=\).*,\1 $_store_intermediate_name," $INTERMEDIATE_CNF_FILE
    
    _cmd="openssl req -config $INTERMEDIATE_CNF_FILE -new -sha512 \
        -key $_intermediate_private_key -out $_intermediate_csr_file $_openssl_pass_arg 2>/dev/null"
    _execute_command "$_cmd" "Failed to generate CSR $_intermediate_csr_file"
}

function _sign_intermediate_csr()
{
    maybe_log "Creating signed certificate - $_intermediate_signed_cert..."
    maybe_log "Using CSR: $_intermediate_csr_file"
    maybe_log "Using cnf file: $ROOTCA_CNF_FILE"
    maybe_log "Using extension: $_intermediate_extension"

    if [[ -z $_store_password ]]; then
        stty -echo
        printf "Enter password for $_intermediate_private_key: "
        read _password
        stty echo
        printf "\n" 
    else
        _password=$_store_password
    fi
    local _openssl_pass_arg="-batch -passin pass:$_password"

    if [[ -z $_time_to_live ]]; then
      _ttl="-days $_intermediate_days_to_live"
    else
      _ttl="-enddate $_time_to_live"
    fi
    maybe_log "Using TTL: $_ttl"

    _cmd="openssl ca -config $ROOTCA_CNF_FILE -extensions $_intermediate_extension \
        $_ttl -notext -md sha512 \
        -in $_intermediate_csr_file -out $_intermediate_signed_cert $_openssl_pass_arg 2>/dev/null"
    _execute_command "$_cmd" "Failed to sign intermediate certificate using $_intermediate_csr_file"
    chmod 444 $_intermediate_signed_cert
}

function create_leaf()
{
    _prepare_leaf_dirs

    [[ ! -f $_leaf_private_key ]] && _generate_key $_leaf_private_key
    [[ ! -f $_leaf_csr_file ]] && _generate_leaf_csr
    [[ ! -f $_leaf_signed_cert ]] && _sign_leaf_csr
}

function _prepare_leaf_dirs()
{
    _create_directories "$_leaf_dirs_list"
    chmod 700 $_leaf_private_key_dir
}

function _generate_leaf_csr()
{
    maybe_log "Creating CSR $_leaf_csr_file..."
    maybe_log "Using cnf file: $INTERMEDIATE_CNF_FILE"

    if [[ -z $_store_password ]]; then
        stty -echo
        printf "Enter password for $_intermediate_private_key: "
        read _password
        stty echo
        printf "\n" 
    else
        _password=$_store_password
    fi
    local _openssl_pass_arg="-batch -passin pass:$_password"
    sed -i.orig -e "s%\(^subjectAltName *=\).*%\1 $_store_san_extensions%" $INTERMEDIATE_CNF_FILE
    [[ ! -z $_store_san_extensions ]] && _request_san_extension="-reqexts SAN"
    sed -i.orig -e "s,\(^commonName_default *=\).*,\1 $_store_leaf_certificate_name," $INTERMEDIATE_CNF_FILE

    _cmd="openssl req -config $INTERMEDIATE_CNF_FILE -new -sha512 \
        -key $_leaf_private_key -out $_leaf_csr_file \
        $_request_san_extension $_openssl_pass_arg 2>/dev/null"
    _execute_command "$_cmd" "Failed to generate CSR $_leaf_csr_file"
}

function _sign_leaf_csr()
{
    maybe_log "Creating signed certificate $_leaf_signed_cert..."
    maybe_log "Using intermediate: $_store_intermediate_name"
    maybe_log "Using CSR: $_leaf_csr_file"
    maybe_log "Using cnf file: $INTERMEDIATE_CNF_FILE"
    maybe_log "Using extension: $_leaf_certificate_type"
    
    if [[ -z $_store_password ]]; then
        stty -echo
        printf "Enter password for $_intermediate_private_key: "
        read _password
        stty echo
        printf "\n" 
    else
        _password=$_store_password
    fi
    local _openssl_pass_arg="-batch -passin pass:$_password"

    if [[ -z $_time_to_live ]]; then
      _ttl="-days $_leaf_days_to_live"
    else
      _ttl="-enddate $_time_to_live"
    fi
    maybe_log "Using TTL: $_ttl"

    _cmd="openssl ca -config $INTERMEDIATE_CNF_FILE -extensions $_leaf_certificate_type \
        $_ttl -notext -md sha512 \
        -in $_leaf_csr_file -out $_leaf_signed_cert $_openssl_pass_arg 2> /dev/null"
    _execute_command "$_cmd" "Failed to sign leaf certificate using $_leaf_csr_file"
    chmod 444 $_leaf_signed_cert
}

function create_truststores()
{    
    [[ ! -f $_jks_truststore ]] && _generate_jks_truststore
    [[ ! -f $_pkcs12_truststore ]] && _generate_pfx_truststore
}

# Due to a limitation of not being able to add OID 2.16.840.1.113894.746875.1.1 to the PKCS12 store, Java cannot read the certs
#   - https://github.com/openssl/openssl/issues/6684
# As a result, we must convert the JKS file to PKCS12, we cannot use openssl to generate the PKCS12 truststore
function _generate_pfx_truststore()
{
    maybe_log "Creating PKCS12 Truststore: $_pkcs12_truststore..."
    
    if [[ -z $_store_password ]]; then
        stty -echo
        printf "Enter password for $_jks_truststore: "
        read _jks_password
        printf "\n"
        printf "Enter password for $_pkcs12_truststore: "
        read _pfx_password
        stty echo
        printf "\n"
    else
        _jks_password=$_store_password
        _pfx_password=$_store_password
    fi
    local _keytool_pass_arg="-srcstorepass $_jks_password -deststorepass $_pfx_password"

    _cmd="keytool -importkeystore -srckeystore $_jks_truststore -destkeystore $_pkcs12_truststore -deststoretype PKCS12 $_keytool_pass_arg 2>/dev/null"
    _execute_command "$_cmd" "Failed to generate truststore $_pkcs12_truststore from $_jks_truststore"
    chmod 644 $_pkcs12_truststore
}

function _generate_jks_truststore()
{
    maybe_log "Creating JKS Truststore: $_jks_truststore..."

    if [[ -z $_store_password ]]; then
        stty -echo
        printf "Enter password for $_jks_truststore: "
        read _password
        stty echo
        printf "\n" 
    else
        _password=$_store_password
    fi
    local _keytool_pass_arg="-storepass $_password"

    maybe_log "Importing rootca: $_root_public_cert..."
    _cmd="keytool -importcert -noprompt -alias rootca -keystore $_jks_truststore \
        -file $_root_public_cert $_keytool_pass_arg 2>/dev/null"
    _execute_command "$_cmd" "Failed to import $_root_public_cert into $_jks_truststore"
    chmod 644 $_jks_truststore
}

function create_keystores()
{
    [[ ! -f $_pkcs12_keystore ]] && _generate_pfx_keystore
    [[ ! -f $_jks_keystore ]] && _generate_jks_keystore
}

function _generate_pfx_keystore()
{
    maybe_log "Creating PKCS12 Keystore: $_pkcs12_keystore..."

    if [[ -z $_store_password ]]; then
        stty -echo
        printf "Enter password for $_leaf_private_key: "
        read _pem_password
        printf "\n"
        printf "Enter password for $_pkcs12_keystore: "
        read _pfx_password
        stty echo
        printf "\n" 
    else
        _pem_password=$_store_password
        _pfx_password=$_store_password
    fi
    local _openssl_pass_arg="-passin pass:$_pem_password -passout pass:$_pfx_password"

    _cmd="openssl pkcs12 -export -inkey $_leaf_private_key -in $_leaf_signed_cert \
        -certfile $_intermediate_signed_cert -out $_pkcs12_keystore $_openssl_pass_arg"
    _execute_command "$_cmd" "failed to generate $_pkcs12_keystore"
    chmod 400 $_pkcs12_keystore
}

function _generate_jks_keystore()
{
    maybe_log "Creating JKS Keystore: $_jks_keystore..."
    
    if [[ -z $_store_password ]]; then
        stty -echo
        printf "Enter password for $_pkcs12_keystore: "
        read _pfx_password
        printf "\n"
        printf "Enter password for $_jks_keystore: "
        read _jks_password
        stty echo
        printf "\n" 
    else
        _pfx_password=$_store_password
        _jks_password=$_store_password
    fi
    local _keytool_pass_arg="-srcstorepass $_pfx_password -deststorepass $_jks_password"
   
    _cmd="keytool -importkeystore -srckeystore $_pkcs12_keystore -srcstoretype PKCS12 \
        -destkeystore $_jks_keystore -deststoretype JKS $_keytool_pass_arg 2>/dev/null"
    _execute_command "$_cmd" "Failed to generate $_jks_keystore"
    chmod 400 $_jks_keystore
}

function zip_certificates()
{
    [[ ! -z $_store_intermediate_name ]] && _tar_truststores
    [[ ! -z $_store_leaf_certificate_name ]] && _tar_keystores

    gzip $_store_zip_name
}

function _tar_truststores()
{
    [[ -f $_intermediate_signed_cert ]] && tar -cPf $_store_zip_name \
        -C $(dirname $_intermediate_signed_cert) $(basename $_intermediate_signed_cert)
    [[ -f $_root_public_cert ]] && tar -rPf $_store_zip_name \
        -C $(dirname $_root_public_cert) $(basename $_root_public_cert)
    [[ -f $_pkcs12_truststore ]] && tar -rPf $_store_zip_name \
        -C $(dirname $_pkcs12_truststore) $(basename $_pkcs12_truststore)
    [[ -f $_jks_truststore ]] && tar -rPf $_store_zip_name \
        -C $(dirname $_jks_truststore) $(basename $_jks_truststore)
}

function _tar_keystores()
{
    [[ -f $_leaf_private_key ]] && tar -rPf $_store_zip_name \
        -C $(dirname $_leaf_private_key) $(basename $_leaf_private_key)
    [[ -f $_leaf_signed_cert ]] && tar -rPf $_store_zip_name \
        -C $(dirname $_leaf_signed_cert) $(basename $_leaf_signed_cert)
    [[ -f $_pkcs12_keystore ]] && tar -rPf $_store_zip_name \
        -C $(dirname $_pkcs12_keystore) $(basename $_pkcs12_keystore)
    [[ -f $_jks_keystore ]] && tar -rPf $_store_zip_name \
        -C $(dirname $_jks_keystore) $(basename $_jks_keystore)
}

_script_name=$(basename $0)
main "$@"
