# Scenario 3 Solution (Spoilers)

NOTE: Please be sure to actually make an attempt at the scenario as this is meant to be a learning exercise.

---------------

## Identification

On `node1`, there is an error similar to the following:

```
INFO  [CoreThread-0] 2021-02-06 03:10:46,757  OutboundHandshakeHandler.java:240 - Failed to properly
handshake with peer 10.101.32.225/10.101.32.225:7001. Closing the channel.
io.netty.handler.codec.DecoderException: javax.net.ssl.SSLHandshakeException: No subject alternative
names present
```

Inspecting the keystore on `node0`, we can verify that this is indeed the case:

```
keytool -list -v -keystore /home/automaton/datastax-ssl-training/scenario3/scenario3-keystore.jks
```

A keystore with a SAN entry would contain something like this:

```
SubjectAlternativeName [
  IPAddress: <ip>
  DNSName: <hostname>
]
```

## Summary

This is a missing SAN (Subject Alternative Name) entry issue causing the handshake failure with `require_endpoint_verification: true`.

## Resolution

A new certificate must be generated with the SAN entries attached. If you would like to do this yourself, you can generate a new certificate using `certificate-authority` (substitute in the proper values):

```
certificate-authority -i datastax-ssl-training -s fixed-scenario3 -e "IP:<ip>,DNS:<hostname>" -p cassandra -z fixed-scenario3
```

And then upload to the node:

```
ctool scp datastax-ssl-training 0 fixed-scenario3.tar.gz /home/automaton
```

Untar after `ssh`'ing to `node0`:

```
tar -xf fixed-scenario3.tar.gz
```

Adjust the `cassandra.yaml` to point to the new keystore and then restart the node.