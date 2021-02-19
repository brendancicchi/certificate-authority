# Scenario 5 Solution (Spoilers)

NOTE: Please be sure to actually make an attempt at the scenario as this is meant to be a learning exercise.

---------------

## Identification

On `node0`, there are messages similar to the following regarding the handshake:

```
INFO  [CoreThread-0] 2021-02-19 22:41:24,080  OutboundHandshakeHandler.java:240 - Failed to properly handshake with peer 10.101.35.199/10.101.35.199:7001. Closing the channel.
io.netty.handler.codec.DecoderException: javax.net.ssl.SSLHandshakeException: Received fatal alert: certificate_unknown
```

On `node1`, the handshake failure message is much more helpful:

```
INFO  [CoreThread-0] 2021-02-19 22:42:28,121  InboundHandshakeHandler.java:331 - Failed to properly handshake with peer /10.101.33.251:38001. Closing the channel.
io.netty.handler.codec.DecoderException: javax.net.ssl.SSLHandshakeException: NotAfter: Fri Feb 19 22:40:11 UTC 2021
```

Inspecting the keystore on `node0`, we can check what the validity of the certificates using the following command:

```
keytool -list -v -keystore /home/automaton/datastax-ssl-training/scenario5/scenario5-keystore.jks
```

This will show something similar to the output below:

```
.
.
.
Creation date: Feb 19, 2021
Entry type: PrivateKeyEntry
Certificate chain length: 2
Certificate[1]:
Owner: CN=scenario5, OU=Support, O=DataStax, ST=CA, C=US
Issuer: CN=datastax-ssl-training, OU=Support, O=DataStax, ST=CA, C=US
Serial number: 1005
Valid from: Fri Feb 19 22:40:02 UTC 2021 until: Fri Feb 19 22:40:11 UTC 2021
.
.
.
Certificate[2]:
Owner: CN=datastax-ssl-training, OU=Support, O=DataStax, ST=CA, C=US
Issuer: CN=rootCA, OU=Support, O=DataStax, ST=CA, C=US
Serial number: 1000
Valid from: Fri Feb 19 22:37:03 UTC 2021 until: Mon Feb 17 22:37:03 UTC 2031
.
.
.
```

Notice that the leaf certificate (`Certificate[1]`) has an expiration date in the past. This is why the node has failed to handshake properly with the other nodes.



## Summary

The leaf certificate on node0 is expired, causing the handshakes to fail.

## Resolution

The resolution is generate a new certificate signed by the same intermediate. Using `certificate-authority`, this would look like:

```
certificate-authority -i datastax-ssl-training -s fixed-scenario5 -e "IP:<ip>,DNS:<hostname>" -p cassandra -z fixed-scenario5
```

And then upload to the node:

```
ctool scp datastax-ssl-training 0 fixed-scenario4.tar.gz /home/automaton
```

Untar to your desired directory after `ssh`'ing to `node0`:

```
tar -xf fixed-scenario4.tar.gz
```

Adjust the `cassandra.yaml` to point to the new keystore and then restart the node.