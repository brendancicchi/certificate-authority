# Scenario 1 Solution (Spoilers)

NOTE: Please be sure to actually make an attempt at the scenario as this is meant to be a learning exercise.

---------------

## Overview

The root of the issue here is that the certificate chain for the keystore is incomplete. The result is that trust cannot be established based on the intermediate. This is a rather common issue that is seen in Support and generally will happen when a customer uses openssl to build the keystore as you need to explicitly specify the chain PEMs when building the PKCS12 file.

## Identification

The incomplete chain can be seen via `keytool`:

```
keytool -list -v -keystore /home/automaton/datastax-ssl-training/scenario1/scenario1.jks -storepass cassandra
```

Important Output:

```
Alias name: 1
Creation date: Feb 2, 2021
Entry type: PrivateKeyEntry
Certificate chain length: 1
Certificate[1]:
Owner: CN=scenario1, OU=Support, O=DataStax, ST=CA, C=US
Issuer: CN=datastax-ssl-training, OU=Support, O=DataStax, ST=CA, C=US
```

Notice that the `PrivateKeyEntry` was issued by `CN=datastax-ssl-training, OU=Support, O=DataStax, ST=CA, C=US` but the chain length shows as **1**. To further validate, we see the truststore only contains the certificates


## Resolution

Convert the keystore to PKCS12:

```
keytool -importkeystore -srckeystore scenario1.jks -srcstorepass cassandra -destkeystore scenario1.p12 -deststoretype PKCS12 -deststorepass cassandra
```

Export the private key from the PKCS12 file:

```
openssl pkcs12 -in scenario1.p12 -passin pass:cassandra -out private.key -nodes -nocerts
```

Export the public certificate from the PKCS12 file:

```
openssl pkcs12 -in scenario1.p12 -passin pass:cassandra -out public.pem -nokeys
```

Export the intermediate and root certificates from the truststore in PEM format

```
keytool -exportcert -rfc -alias rootca -file root.pem -keystore datastax-ssl-training-truststore.jks -storepass cassandra
keytool -exportcert -rfc -alias datastax-ssl-training -file intermediate.pem -keystore datastax-ssl-training-truststore.jks -storepass cassandra
```

Concatenate the intermediate and root PEM certificates into a single file:

```
cat intermediate.pem root.pem > chain.pem
```

Export a new PKCS12 file using the files collected above

```
openssl pkcs12 -export -inkey private.key -in public.pem -certfile chain.pem -passout pass:cassandra -out fixed.p12
```

Convert the new PKCS12 file back to JKS

```
keytool -importkeystore -srckeystore fixed.p12 -srcstoretype PKCS12 -srcstorepass cassandra -destkeystore fixed.jks -deststorepass cassandra
```

Either adjust the `cassandra.yaml` to point to the new keystore or rearrange the keystores such that the cassandra.yaml points to our fixed keystore.

Finally restart DSE.