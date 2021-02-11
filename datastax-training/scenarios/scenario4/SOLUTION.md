# Scenario 4 Solution (Spoilers)

NOTE: Please be sure to actually make an attempt at the scenario as this is meant to be a learning exercise.

---------------

## Identification

On `node0`, there is an error similar to the following:

```
ERROR [ACCEPT-/10.101.32.33] 2021-02-06 16:48:47,993  MessagingService.java:1411 - SSL handshake error for inbound connection from Socket[addr=/10.101.36.156,port=44394,localport=7001]
javax.net.ssl.SSLHandshakeException: no cipher suites in common
```

On `node1`, we actually see a different error:

```
ERROR [ACCEPT-/10.101.36.156] 2021-02-06 16:48:32,568  MessagingService.java:1411 - SSL handshake error for inbound connection from Socket[addr=/10.101.32.33,port=45562,localport=7001]
javax.net.ssl.SSLHandshakeException: Empty server certificate chain
```

Inspecting the keystore on `node0`, we can see that there is no PrivateKeyEntry in the keystore:

```
keytool -list -keystore /home/automaton/datastax-ssl-training/scenario4/scenario4-keystore.jks
```

We only see `trustedCertEntry` entries, something similar to below:

```
Keystore type: JKS
Keystore provider: SUN

Your keystore contains 3 entries

rootca, Feb 8, 2021, trustedCertEntry,
Certificate fingerprint (SHA1): 12:FD:8B:96:A3:96:51:2E:32:50:8B:63:86:AE:8A:83:3A:BD:0E:72
scenario4, Feb 9, 2021, trustedCertEntry,
Certificate fingerprint (SHA1): F8:F8:98:0E:97:6B:03:3F:4C:D3:21:1B:1E:1F:59:A0:77:25:70:03
datastax-ssl-training, Feb 8, 2021, trustedCertEntry,
Certificate fingerprint (SHA1): 4E:AB:C7:FD:DC:6D:6E:66:A3:2E:8E:7A:00:65:3F:7F:98:84:2D:F7
```

## Summary

There is no PrivateKeyEntry in the keystore in use by the node, so the keystore is invalid.

## Resolution

Since the key is completely missing, a new key/certificate must be generated. You can generate a new certificate using `certificate-authority` (substitute in the proper values):

```
certificate-authority -i datastax-ssl-training -s fixed-scenario4 -e "IP:<ip>,DNS:<hostname>" -p cassandra -z fixed-scenario4
```

And then upload to the node:

```
ctool scp datastax-ssl-training 0 fixed-scenario4.tar.gz /home/automaton
```

Untar after `ssh`'ing to `node0`:

```
tar -xf fixed-scenario4.tar.gz
```

Adjust the `cassandra.yaml` to point to the new keystore and then restart the node.