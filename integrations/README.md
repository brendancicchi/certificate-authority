## CTOOL Integration

### Pre-Requisites
* The steps under **certificate-authority**'s setup must already be completed
* The cluster must already be deployed via **ctool** with DSE installed
Configure the _CAPS-LOCKED_ variables at the top of the of the script for **ctool** customizations and configuring the path to **certificate-authority**. The default password to be applied wherever necessary can also be changed.
```bash
PROVIDER="nebula"
CTOOL="PYENV_VERSION=ctool ctool --provider=${PROVIDER}"
CA="$(dirname $0)/../certificate-authority.sh"
PASSWORD="cassandra"
```
**Limitation:** The password cannot be changed once the root certificate is created, or if the root certificate was already created

### Usage
The *ctool-deploy-certs.sh* script allows you to easily distribute certificates generated via **certificate-authority** to an existing cluster deployed via **ctool**. The help output for **ctool-deploy-certs** can be seen below:
```
Usage:
-> Mandatory Arguments:
    -c                       CTOOL cluster name
-> Optional Arguments:
    -a                       Use mutual authentication (2-way SSL) for clients
    -h                       Display this help message.
    -o                       Allow optional client connections
    -r                       Restart the nodes in parallel
```
