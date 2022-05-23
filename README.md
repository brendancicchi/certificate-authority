# certificate-authority README

### Setup

Clone this repository locally:

```bash
git clone https://github.com/brendancicchi/certificate-authority.git
```

Copy the _resources/*.cnf files_ to a desired location in your file system. For example:

```bash
mkdir -p ~/.ssl/{cnf_files,ca}
cp resources/*.cnf ~/.ssl/cnf_files
```

Configure the _CAPS-LOCKED_ variables at the top of the _conf/ssl-var-configurations.sh_ as seen below:

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

### Usage
The help output for **certificate-authority** can be seen below:
```
Usage:
    -c <client_cert_name>    Create a client certificate with given name
                               - Requires -i <intermediate_name> to sign
    -e <IP:ip,DNS:host,...>  SAN list to be used for server or client certificate
                               - Requires -s <server_cert_name> or -c <client_cert_name>
    -h                       Display this help message.
    -i <intermediate_name>   Create or use intermediate with given name
                               - The name should be the same as the CN
    -l                       List created intermediates
                               - Use with -i <intermediate> to show leaf certificates
    -p <password>            Password to be applied to ALL openssl and keytool commands
                               - This is not secure and only meant for dev environment purposes
                               - Removes all prompting from the user
    -r                       Create the rootca key and certificate
    -s <server_cert_name>    Create a server certificate with given name
                               - Requires -i <intermediate_name> to sign
    -t <seconds>             TTL to provide to any certificate created (Unit: seconds)
    -v                       Generate verbose output
    -x <certificate_name>    Revoke the named certificate
                               - Use with -i <intermediate> to specify a leaf certificate
                               - Otherwise assumes intermediate certificate
    -z <zip_name>            Zip up the relevant certificates, keys, and stores
                               - Use with -i <intermediate> to only zip the public chain and stores
                               - Use with -c or -s to include the keys and keystores
```

# Integrations

* [CTool Integration](integrations/README.md#ctool-integration)

# SSL Training

* [DataStax SSL Training](datastax-training/README.md)
