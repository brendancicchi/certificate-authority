# Scenario 1 Solution (Spoilers)

NOTE: Please be sure to actually make an attempt at the scenario as this is meant to be a learning exercise.

---------------

## Identification

On `node0`, there is an error similar to the following:

```
INFO  [CoreThread-0] 2021-02-11 18:42:00,613  OutboundHandshakeHandler.java:240 - Failed to properly
handshake with peer 10.101.36.20/10.101.36.20:7001. Closing the channel.
io.netty.handler.codec.DecoderException: javax.net.ssl.SSLHandshakeException: Received fatal alert: b
ad_certificate
```

On `node1`, there is an error similar to the following:

```
INFO  [CoreThread-0] 2021-02-11 18:43:53,567  OutboundHandshakeHandler.java:240 - Failed to properly
handshake with peer 10.101.32.199/10.101.32.199:7001. Closing the channel.
io.netty.handler.codec.DecoderException: javax.net.ssl.SSLHandshakeException: No trusted certificate
found
```

Inspecting the truststores on both `node0` and `node1` via a command similar to:

```
keytool -list -v -keystore /home/automaton/datastax-ssl-training/scenario1/datastax-ssl-training-truststore.jks -storepass cassandra
```

Trust is being established based on the root certificate:

```
Your keystore contains 1 entry

Alias name: rootca
Creation date: Feb 11, 2021
Entry type: trustedCertEntry

Owner: CN=rootCA, OU=Support, O=DataStax, ST=CA, C=US
Issuer: CN=rootCA, OU=Support, O=DataStax, ST=CA, C=US
```

However, if we inspect the keystore on `node0`:

```
keytool -list -v -keystore /home/automaton/datastax-ssl-training/scenario1/scenario1.jks -storepass cassandra
```

The chain is incomplete:

```
Alias name: 1
Creation date: Feb 2, 2021
Entry type: PrivateKeyEntry
Certificate chain length: 1
Certificate[1]:
Owner: CN=scenario1, OU=Support, O=DataStax, ST=CA, C=US
Issuer: CN=datastax-ssl-training, OU=Support, O=DataStax, ST=CA, C=US
```

Notice that the `PrivateKeyEntry` was issued by `CN=datastax-ssl-training, OU=Support, O=DataStax, ST=CA, C=US` but the chain length shows as **1**. This means that trust cannot be established because the privatekey only knows the public information through the intermediate, there is no knowledge of the root.

## Summary

The root of the issue here is that the certificate chain for the keystore is incomplete and the nodes are set up to use the root certificate to establish trust. The result is that trust cannot be established based on the intermediate, which is the highest level available within the signed certificate chain. 

This is a rather common issue that is seen in Support. An incomplete PKCS12 export when creating the keystore from the key and signed certificate yields a keystore such as the one in this scenario. Typically customers will be using something like DigiCert and defaulting to the `cacerts` file for trust, but the `cacerts` file actually will only have the root certificate often times rather than the necessary signing intermediate.

## Resolution

In order to fix the certificate chain of the keystore, first convert the keystore to PKCS12:

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

Export a new PKCS12 file but include the intermediate certificate already available:

```
openssl pkcs12 -export -inkey private.key -in public.pem -certfile datastax-ssl-training.cert.pem -passout pass:cassandra -out fixed.p12
```

Convert the new PKCS12 file back to JKS

```
keytool -importkeystore -srckeystore fixed.p12 -srcstoretype PKCS12 -srcstorepass cassandra -destkeystore fixed.jks -deststorepass cassandra
```

Either adjust the `cassandra.yaml` to point to the new keystore or rearrange the keystores on the file system such that the existing cassandra.yaml points to our fixed keystore.

Finally restart DSE.