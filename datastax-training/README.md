# DataStax SSL/TLS Support Training

## PreRequisites

* A `ctool` environment has already been configured by following these [instructions](https://docsreview.sjc.dsinternal.org/en/dse/doc/ctool/ctool/ctoolGettingStarted.html#ctoolGettingStarted)
* The `certificate-authority` setup has been completed per the steps in the [README](../README.md#setup)

## Setup

Configure the _CAPS-LOCKED_ variables in the configuration block, at the top of `run-scenario.sh`, as necessary to work with your environment:

```
##### Begin Configurations #####
export PROVIDER="nebula"
export CTOOL="PYENV_VERSION=2.7.17/envs/ctool ctool --provider=${PROVIDER}"
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

The first scenario launched can take 10 minutes as the instances need to be launched as well as DSE configured and started. Subsequent scenario configurations will be much quicker.

If the `ctool` cluster is manually destroyed, you must remove the `certificate-authority` entries for the cluster manually as well before relaunching.

```
certificate-authority -x {CLUSTER_NAME} -p {PASSWORD}
```

## Scenarios

The **Solution** links contain spoilers. Please attempt to correct the scenario yourself before viewing any solutions. Scenarios are independent of each other so you can move onto the next scenario and redeploy a scenario later even without solving it. DSE must be in a configuration that allows it to start prior to any scenario deployments. 

* Scenario 1 - `./run-scenario.sh -s 1` -> [Solution](scenarios/scenario1/SOLUTION.md)
* Scenario 2 - `./run-scenario.sh -s 2` -> [Solution](scenarios/scenario2/SOLUTION.md)
* Scenario 3 - `./run-scenario.sh -s 3` -> [Solution](scenarios/scenario3/SOLUTION.md)
* Scenario 4 - `./run-scenario.sh -s 4` -> [Solution](scenarios/scenario4/SOLUTION.md)
