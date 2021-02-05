# Scenario 2 Solution (Spoilers)

NOTE: Please be sure to actually make an attempt at the scenario as this is meant to be a learning exercise.

---------------

## Overview

This is a pretty typical cipher suite incompatibility issue. The ciphers listed on `node0` are actually all restricted by the JVM and thus rejected. These are all older ciphers introduced in `TLSv1` and use a `SHA1` hash.

## Identification

Error message from log:

```
ERROR [ACCEPT-/10.101.34.237] 2021-02-04 14:43:34,999  MessagingService.java:1411 - SSL handshake err
or for inbound connection from Socket[addr=/10.101.34.194,port=52954,localport=7001]
javax.net.ssl.SSLHandshakeException: no cipher suites in common
```

The easiest way to identify what is going on is to leverage `openssl s_client`. All of the keys and certificates necessary to test this can be found under `/home/automaton/datastax-ssl-training/scenario2/`.

Attempt a connection with `s_client` to the other node in the cluster on the storage port. Remember that this is a 2-way SSL connection as configured in the `cassandra.yaml`, so `s_client` needs to provide a key:

```
openssl s_client -connect node1:7001 \
  -key /home/automaton/datastax-ssl-training/scenario2/scenario2.key.pem \
  -cert /home/automaton/datastax-ssl-training/scenario2/scenario2.cert.pem \
  -CAfile /home/automaton/datastax-ssl-training/scenario2/ca-datastax-ssl-training-chain.certs.pem
```

That connection was successful and the cipher and protocol used were:

```
SSL-Session:
    Protocol  : TLSv1.2
    Cipher    : ECDHE-RSA-AES256-GCM-SHA384
```

The cassandra.yaml lists the following cipher suites:

```
    cipher_suites:
    -   TLS_RSA_WITH_AES_128_CBC_SHA
    -   TLS_RSA_WITH_AES_256_CBC_SHA
    -   TLS_DHE_RSA_WITH_AES_128_CBC_SHA
    -   TLS_DHE_RSA_WITH_AES_256_CBC_SHA
    -   TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA
    -   TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
```

Trying with one of those ciphers, `TLS_RSA_WITH_AES_128_CBC_SHA` (`AES128-SHA` for [openssl](https://www.openssl.org/docs/man1.0.2/man1/ciphers.html)):

```
openssl s_client -connect node1:7001 \
  -key /home/automaton/datastax-ssl-training/scenario2/scenario2.key.pem \
  -cert /home/automaton/datastax-ssl-training/scenario2/scenario2.cert.pem \
  -CAfile /home/automaton/datastax-ssl-training/scenario2/ca-datastax-ssl-training-chain.certs.pem \
  -cipher AES128-SHA
```

Results in an immediate handshake failure:

```
>>> TLS 1.2  [length 0005]
    16 03 01 00 5e
>>> TLS 1.2 Handshake [length 005e], ClientHello
    01 00 00 5a 03 03 3f d5 c5 af cd 4a 8e 8a e4 d6
    b9 ba 66 e2 9f 1f 25 1e 4c 8f 64 39 96 53 62 bb
    34 fd cd 4f 3c 6b 00 00 04 00 2f 00 ff 01 00 00
    2d 00 23 00 00 00 0d 00 20 00 1e 06 01 06 02 06
    03 05 01 05 02 05 03 04 01 04 02 04 03 03 01 03
    02 03 03 02 01 02 02 02 03 00 0f 00 01 01
<<< TLS 1.2  [length 0005]
    15 03 03 00 02
<<< TLS 1.2 Alert [length 0002], fatal handshake_failure
    02 28
139978445969048:error:14077410:SSL routines:SSL23_GET_SERVER_HELLO:sslv3 alert handshake failure:s23_clnt.c:769:
```

Since this is cipher dependent, we can look at the `cassandra.yaml` first on `node1` to see what is configured. Since the `server_encryption_options.ciphers_suites` is not specified on node1, it would default to allowing all ciphers permitted by the socket. Next, let's check what the JVM is configured to allow via `jdk.tls.disabledAlgorithms` on `node1`:

```
jdk.tls.disabledAlgorithms=SHA1, SSLv3, RC4, DES, MD5withRSA, DH keySize < 1024, \
    EC keySize < 224, 3DES_EDE_CBC, anon, NULL
```

We do see that all `SHA1` ciphers are disabled on the socket, and since all the ciphers in `node0`'s allow list are `SHA1`, this is why they all fail.

## Resolution

There are multiple solutions depending on what the desired outcome. Here are the two most optimal solutions:

- Comment or remove the `server_encryption_options.ciphers_suite` from the `cassandra.yaml` allowing DSE to use all ciphers allowed by the JVM

- Adjust the `server_encryption_options.ciphers_suite` in the `cassandra.yaml` to only include compatible ciphers
  - Compatibility of [ciphers](https://www.openssl.org/docs/man1.0.2/man1/ciphers.html) can be tested via `openssl s_client`

I would also recommend ensuring that `node0` and `node1`'s JVM configurations match in the `java.security` file.