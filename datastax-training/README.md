# DataStax SSL/TLS Support Training

## PreRequisites

* A `ctool` environment has already been configured by following these [instructions](https://docsreview.sjc.dsinternal.org/en/dse/doc/ctool/ctool/ctoolGettingStarted.html#ctoolGettingStarted)
* The `certificate-authority` setup has been completed per the steps in the [README](../README.md#setup)

## Setup

Configure the _CAPS-LOCKED_ variables at the top of `run-scenario.sh`, namely:

```
##### Begin Configurations #####
export PROVIDER="nebula"
export CTOOL="PYENV_VERSION=2.7.17/envs/ctool ctool --provider=${PROVIDER}"
export CA="$(dirname $(echo "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")"))/certificate-authority.sh"
export PASSWORD="cassandra"
export TMP="/tmp"
CLUSTER_NAME="datastax-ssl-training"
INSTANCE_TYPE="c4.large"
DSE_VERSION="6.8.9"
##### End Configurations #####
```

## Usage

The help output for `run-scenario.sh` can be seen below:

```
Usage:
    -h                        Display this help message.
    -s <number>               Scenario to run
    -x                        Destroy training environment
```

## Scenarios

* [Scenario 1](scenarios/scenario1/README.md) - `./run-scenario.sh -s 1`
* [Scenario 2](scenarios/scenario2/README.md) - `./run-scenario.sh -s 2`