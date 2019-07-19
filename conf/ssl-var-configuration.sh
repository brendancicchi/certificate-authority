#!/usr/bin/env bash

##### Begin Common Configurations #####
# Root directory for all created certificates
SSL_DIR=~/.ssl

# Root directory for root and intermediate certificates
ROOTCA_DIR=$SSL_DIR/ca

# Location for cnf files
ROOTCA_CNF_FILE=$SSL_DIR/cnf_files/rootca.cnf
INTERMEDIATE_CNF_FILE=$SSL_DIR/cnf_files/intermediate.cnf

##### End of Common Configurations #####

##### DISCLAIMER ######
# The below section should not be touched by the typical user
##### END DISCLAIMER ######

_flag_list_certs=
_flag_rootca=
_store_intermediate_name=
_store_leaf_certificate_name=
_flag_server_certificate=
_flag_client_certificate=
_leaf_certificate_type=
_store_san_extensions=
_store_revoke_name=
_store_zip_name=
_store_password=

_root_private_key_dir="$ROOTCA_DIR/private"
_root_private_key="$_root_private_key_dir/ca.key.pem"
_root_public_certs_dir="$ROOTCA_DIR/certs"
_root_public_cert="$_root_public_certs_dir/ca.cert.pem"
_root_crl_dir="$ROOTCA_DIR/crl"
_root_new_certs_dir="$ROOTCA_DIR/newcerts"
_root_index_file="$ROOTCA_DIR/index.txt"
_root_serial_file="$ROOTCA_DIR/serial"
_root_rand_file="$_root_private_key_dir/.rand"
_root_crlnumber="$ROOTCA_DIR/crlnumber"
_root_crl="$_root_crl_dir/ca.crl.pem"
_root_extension="v3_ca"
_root_days_to_live="7300"
_root_dirs_list="$_root_private_key_dir
    $_root_public_certs_dir
    $_root_crl_dir
    $_root_new_certs_dir
    $_root_crlnumber"

function source_intermediate_vars() 
{
    _intermediate_dir="$ROOTCA_DIR/intermediates/intermediate-$1"
    _intermediate_private_key_dir="$_intermediate_dir/private"
    _intermediate_private_key="$_intermediate_private_key_dir/$1.key.pem"
    _intermediate_public_certs_dir="$_intermediate_dir/certs"
    _intermediate_signed_cert="$_intermediate_public_certs_dir/$1.cert.pem"
    _intermediate_csr_dir="$_intermediate_dir/csr"
    _intermediate_csr_file="$_intermediate_csr_dir/$1.csr.pem"
    _intermediate_crl_dir="$_intermediate_dir/crl"
    _intermediate_new_certs_dir="$_intermediate_dir/newcerts"
    _intermediate_index_file="$_intermediate_dir/index.txt"
    _intermediate_serial_file="$_intermediate_dir/serial"
    _intermediate_rand_file="$_intermediate_private_key_dir/.rand"
    _intermediate_crlnumber="$_intermediate_dir/crlnumber"
    _intermediate_crl="$_intermediate_crl_dir/ca.crl.pem"
    _intermediate_cnf_file="$INTERMEDIATE_CNF_FILE"
    _intermediate_extension="v3_intermediate_ca"
    _intermediate_days_to_live="3650"
    _intermediate_chain="$_intermediate_public_certs_dir/ca-$1-chain.certs.pem"
    _truststore_dir="$_intermediate_dir/truststores"
    _jks_truststore="$_truststore_dir/$1-truststore.jks"
    _pkcs12_truststore="$_truststore_dir/$1-truststore.pfx"

    _intermediate_dirs_list="$_intermediate_private_key_dir
        $_intermediate_public_certs_dir
        $_intermediate_csr_dir
        $_intermediate_crl_dir
        $_intermediate_new_certs_dir
        $_truststore_dir"

    push_ssl_intermediate_cnf_paths
}

function source_leaf_vars() {
    _leaf_dir="$2/leaves/leaf-$1"
    _leaf_private_key_dir="$_leaf_dir/private"
    _leaf_private_key="$_leaf_private_key_dir/$1.key.pem"
    _leaf_csr_dir="$_leaf_dir/csr"
    _leaf_csr_file="$_leaf_csr_dir/$1.csr.pem"
    _leaf_public_certs_dir="$_leaf_dir/certs"
    _leaf_signed_cert="$_leaf_public_certs_dir/$1.cert.pem"
    _leaf_days_to_live="365"
    _keystore_dir="$_leaf_dir/keystores"
    _pkcs12_keystore="$_keystore_dir/$1-keystore.pfx"
    _jks_keystore="$_keystore_dir/$1-keystore.jks"

    _leaf_dirs_list="$_leaf_private_key_dir
        $_leaf_csr_dir
        $_leaf_public_certs_dir
        $_keystore_dir"
}

# LibreSSL does not allow passing environment variables in config files
# So as a workaround, set them manually in the CNF files
function push_ssl_rootca_cnf_paths()
{
    sed -i .orig -e "s,\(^certs *=\).*,\1 $_root_public_certs_dir," \
        -e "s,\(^crl_dir *=\).*,\1 $_root_crl_dir," \
        -e "s,\(^new_certs_dir *=\).*,\1 $_root_new_certs_dir," \
        -e "s,\(^database *=\).*,\1 $_root_index_file," \
        -e "s,\(^serial *=\).*,\1 $_root_serial_file," \
        -e "s,\(^RANDFILE *=\).*,\1 $_root_rand_file," \
        -e "s,\(^private_key *=\).*,\1 $_root_private_key," \
        -e "s,\(certificate *=\).*,\1 $_root_public_cert," \
        -e "s,\(crlnumber *=\).*,\1 $_root_crlnumber," \
        -e "s,\(crl *=\).*,\1 $_root_crl," \
        $ROOTCA_CNF_FILE
}

function push_ssl_intermediate_cnf_paths()
{
    sed -i .orig -e "s,\(^certs *=\).*,\1 $_intermediate_public_certs_dir," \
        -e "s,\(^crl_dir *=\).*,\1 $_intermediate_crl_dir," \
        -e "s,\(^new_certs_dir *=\).*,\1 $_intermediate_new_certs_dir," \
        -e "s,\(^database *=\).*,\1 $_intermediate_index_file," \
        -e "s,\(^serial *=\).*,\1 $_intermediate_serial_file," \
        -e "s,\(^RANDFILE *=\).*,\1 $_intermediate_rand_file," \
        -e "s,\(^private_key *=\).*,\1 $_intermediate_private_key," \
        -e "s,\(certificate *=\).*,\1 $_intermediate_signed_cert," \
        -e "s,\(crlnumber *=\).*,\1 $_intermediate_crlnumber," \
        -e "s,\(crl *=\).*,\1 $_intermediate_crl," \
        $INTERMEDIATE_CNF_FILE
}

push_ssl_rootca_cnf_paths