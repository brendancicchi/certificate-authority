# certificate-authority README

To run this script, copy the _resources/*.cnf files_ to your desired location
Configure the CAPS-LOCKED variables at the top of the _conf/ssl-var-configurations.sh_

```bash
##### Begin Common Configurations #####
# Root directory for all created certificates
SSL_DIR=~/.ssl

# Root directory for root and intermediate certificates
ROOTCA_DIR=$SSL_DIR/ca

# Location for cnf files
ROOTCA_CNF_FILE=$SSL_DIR/cnf_files/rootca.cnf
INTERMEDIATE_CNF_FILE=$SSL_DIR/cnf_files/intermediate.cnf

##### End of Common Configurations #####
```

The usage for **certificate-authority** can be seen below:
```
    Usage:
        -h                       Display this help message.
        -l                       List created intermediates
                                   - Use with -i <intermediate> to show leaf certificates
        -r                       Create the rootca key and certificate
        -i <intermediate_name>   Create or use intermediate with given name
                                   - The name should be the same as the CN
        -s <server_cert_name>    Create a server certificate with given name
                                   - Requires -i <intermediate_name> to sign
        -c <client_cert_name>    Create a client certificate with given name
                                   - Requires -i <intermediate_name> to sign
        -e <IP:ip,DNS:host,...>  SAN list to be used for server or client certificate
                                   - Requires -s <server_cert_name> or -c <client_cert_name>
        -x <certificate_name>    Revoke the named certificate
                                   - Use with -i <intermediate> to specify a leaf certificate
                                   - Otherwise assumes intermediate certificate
        -z <zip_name>            Zip up the relevant certificates, keys, and stores
                                   - Use with -i <intermediate> to only zip the public chain and stores
                                   - Use with -c or -s to include the keys and keystores
```
