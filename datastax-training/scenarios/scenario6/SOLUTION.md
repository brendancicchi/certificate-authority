# Scenario 6 Solution (Spoilers)

NOTE: Please be sure to actually make an attempt at the scenario as this is meant to be a learning exercise.

---------------

## Identification

On `node0`, there is an error similar to the following:

```
INFO  [CoreThread-0] 2021-07-30 03:46:12,528  OutboundHandshakeHandler.java:240 - Failed to properly handshake with peer 10.101.34.80/10.101.34.80:7001. Closing the channel.
io.netty.handler.codec.DecoderException: javax.net.ssl.SSLHandshakeException: Received fatal alert: bad_certificate
        at io.netty.handler.codec.ByteToMessageDecoder.callDecode(ByteToMessageDecoder.java:459)
        at io.netty.handler.codec.ByteToMessageDecoder.channelRead(ByteToMessageDecoder.java:265)
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:362)
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:348)
        at io.netty.channel.AbstractChannelHandlerContext.fireChannelRead(AbstractChannelHandlerContext.java:340)
        at io.netty.channel.DefaultChannelPipeline$HeadContext.channelRead(DefaultChannelPipeline.java:1434)
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:362)
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:348)
        at io.netty.channel.DefaultChannelPipeline.fireChannelRead(DefaultChannelPipeline.java:965)
        at io.netty.channel.epoll.AbstractEpollStreamChannel$EpollStreamUnsafe.epollInReady(AbstractEpollStreamChannel.java:808)
        at io.netty.channel.epoll.EpollEventLoop.processReady(EpollEventLoop.java:474)
        at org.apache.cassandra.concurrent.EpollTPCEventLoopGroup$SingleCoreEventLoop.processEpollEvents(EpollTPCEventLoopGroup.java:1016)
        at org.apache.cassandra.concurrent.EpollTPCEventLoopGroup$SingleCoreEventLoop.processEvents(EpollTPCEventLoopGroup.java:984)
        at org.apache.cassandra.concurrent.EpollTPCEventLoopGroup$SingleCoreEventLoop.run(EpollTPCEventLoopGroup.java:538)
        at io.netty.util.concurrent.SingleThreadEventExecutor$5.run(SingleThreadEventExecutor.java:884)
        at io.netty.util.concurrent.FastThreadLocalRunnable.run(FastThreadLocalRunnable.java:30)
        at java.lang.Thread.run(Thread.java:748)
        at org.apache.cassandra.utils.concurrent.InlinedThreadLocalThread.run(InlinedThreadLocalThread.java:251)
Caused by: javax.net.ssl.SSLHandshakeException: Received fatal alert: bad_certificate
        at sun.security.ssl.Alert.createSSLException(Alert.java:131)
        at sun.security.ssl.Alert.createSSLException(Alert.java:117)
        at sun.security.ssl.TransportContext.fatal(TransportContext.java:311)
        at sun.security.ssl.Alert$AlertConsumer.consume(Alert.java:293)
        at sun.security.ssl.TransportContext.dispatch(TransportContext.java:185)
        at sun.security.ssl.SSLTransport.decode(SSLTransport.java:152)
        at sun.security.ssl.SSLEngineImpl.decode(SSLEngineImpl.java:575)
        at sun.security.ssl.SSLEngineImpl.readRecord(SSLEngineImpl.java:531)
        at sun.security.ssl.SSLEngineImpl.unwrap(SSLEngineImpl.java:398)
        at sun.security.ssl.SSLEngineImpl.unwrap(SSLEngineImpl.java:377)
        at javax.net.ssl.SSLEngine.unwrap(SSLEngine.java:626)
        at io.netty.handler.ssl.SslHandler$SslEngineType$3.unwrap(SslHandler.java:294)
        at io.netty.handler.ssl.SslHandler.unwrap(SslHandler.java:1275)
        at io.netty.handler.ssl.SslHandler.decodeJdkCompatible(SslHandler.java:1177)
        at io.netty.handler.ssl.SslHandler.decode(SslHandler.java:1221)
        at io.netty.handler.codec.ByteToMessageDecoder.decodeRemovalReentryProtection(ByteToMessageDecoder.java:489)
        at io.netty.handler.codec.ByteToMessageDecoder.callDecode(ByteToMessageDecoder.java:428)
        ... 17 common frames omitted
```

On `node1`, the error is similar to the following:

```
INFO  [CoreThread-0] 2021-07-30 03:49:16,660  OutboundHandshakeHandler.java:240 - Failed to properly handshake with peer 10.101.36.8/10.101.36.8:7001. Closing the channel.
io.netty.handler.codec.DecoderException: javax.net.ssl.SSLHandshakeException: No trusted certificate found
        at io.netty.handler.codec.ByteToMessageDecoder.callDecode(ByteToMessageDecoder.java:459)
        at io.netty.handler.codec.ByteToMessageDecoder.channelRead(ByteToMessageDecoder.java:265)
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:362)
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:348)
        at io.netty.channel.AbstractChannelHandlerContext.fireChannelRead(AbstractChannelHandlerContext.java:340)
        at io.netty.channel.DefaultChannelPipeline$HeadContext.channelRead(DefaultChannelPipeline.java:1434)
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:362)
        at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:348)
        at io.netty.channel.DefaultChannelPipeline.fireChannelRead(DefaultChannelPipeline.java:965)
        at io.netty.channel.epoll.AbstractEpollStreamChannel$EpollStreamUnsafe.epollInReady(AbstractEpollStreamChannel.java:808)
        at io.netty.channel.epoll.EpollEventLoop.processReady(EpollEventLoop.java:474)
        at org.apache.cassandra.concurrent.EpollTPCEventLoopGroup$SingleCoreEventLoop.processEpollEvents(EpollTPCEventLoopGroup.java:1016)
        at org.apache.cassandra.concurrent.EpollTPCEventLoopGroup$SingleCoreEventLoop.processEvents(EpollTPCEventLoopGroup.java:984)
        at org.apache.cassandra.concurrent.EpollTPCEventLoopGroup$SingleCoreEventLoop.run(EpollTPCEventLoopGroup.java:538)
        at io.netty.util.concurrent.SingleThreadEventExecutor$5.run(SingleThreadEventExecutor.java:884)
        at io.netty.util.concurrent.FastThreadLocalRunnable.run(FastThreadLocalRunnable.java:30)
        at java.lang.Thread.run(Thread.java:748)
        at org.apache.cassandra.utils.concurrent.InlinedThreadLocalThread.run(InlinedThreadLocalThread.java:251)
Caused by: javax.net.ssl.SSLHandshakeException: No trusted certificate found
        at sun.security.ssl.Alert.createSSLException(Alert.java:131)
        at sun.security.ssl.TransportContext.fatal(TransportContext.java:324)
        at sun.security.ssl.TransportContext.fatal(TransportContext.java:267)
        at sun.security.ssl.TransportContext.fatal(TransportContext.java:262)
        at sun.security.ssl.CertificateMessage$T12CertificateConsumer.checkServerCerts(CertificateMessage.java:654)
        at sun.security.ssl.CertificateMessage$T12CertificateConsumer.onCertificate(CertificateMessage.java:473)
        at sun.security.ssl.CertificateMessage$T12CertificateConsumer.consume(CertificateMessage.java:369)
        at sun.security.ssl.SSLHandshake.consume(SSLHandshake.java:377)
        at sun.security.ssl.HandshakeContext.dispatch(HandshakeContext.java:444)
        at sun.security.ssl.SSLEngineImpl$DelegatedTask$DelegatedAction.run(SSLEngineImpl.java:968)
        at sun.security.ssl.SSLEngineImpl$DelegatedTask$DelegatedAction.run(SSLEngineImpl.java:955)
        at java.security.AccessController.doPrivileged(Native Method)
        at sun.security.ssl.SSLEngineImpl$DelegatedTask.run(SSLEngineImpl.java:902)
        at io.netty.handler.ssl.SslHandler.runDelegatedTasks(SslHandler.java:1435)
        at io.netty.handler.ssl.SslHandler.unwrap(SslHandler.java:1343)
        at io.netty.handler.ssl.SslHandler.decodeJdkCompatible(SslHandler.java:1177)
        at io.netty.handler.ssl.SslHandler.decode(SslHandler.java:1221)
        at io.netty.handler.codec.ByteToMessageDecoder.decodeRemovalReentryProtection(ByteToMessageDecoder.java:489)
        at io.netty.handler.codec.ByteToMessageDecoder.callDecode(ByteToMessageDecoder.java:428)
        ... 17 common frames omitted
Caused by: sun.security.validator.ValidatorException: No trusted certificate found
        at sun.security.validator.SimpleValidator.buildTrustedChain(SimpleValidator.java:398)
        at sun.security.validator.SimpleValidator.engineValidate(SimpleValidator.java:135)
        at sun.security.validator.Validator.validate(Validator.java:271)
        at sun.security.ssl.X509TrustManagerImpl.validate(X509TrustManagerImpl.java:315)
        at sun.security.ssl.X509TrustManagerImpl.checkTrusted(X509TrustManagerImpl.java:278)
        at sun.security.ssl.X509TrustManagerImpl.checkServerTrusted(X509TrustManagerImpl.java:141)
        at com.datastax.bdp.transport.common.DseReloadableTrustManager.checkServerTrusted(DseReloadableTrustManager.java:146)
        at sun.security.ssl.CertificateMessage$T12CertificateConsumer.checkServerCerts(CertificateMessage.java:632)
        ... 31 common frames omitted
```

When looking at the keystore on `node0`, we can see that the certificate is a self-signed certificate and therefore not a part of our trust chain.

```
Alias name: 1
Creation date: Jul 30, 2021
Entry type: PrivateKeyEntry
Certificate chain length: 1
Certificate[1]:
Owner: CN=node0, OU=Support, O=DataStax, ST=CA, C=US
Issuer: CN=node0, OU=Support, O=DataStax, ST=CA, C=US
```

Notice that the owner and issue are in fact the same.

## Summary

The certificate on `node0` is a self-signed certificate, causing the handshakes to fail.

## Resolution

The resolution is to generate a new certificate that is correctly signed.

```
certificate-authority -i datastax-ssl-training -s fixed-scenario6 -e "IP:<ip>,DNS:<hostname>" -p cassandra -z fixed-scenario6
```

And then upload to the node:

```
ctool scp datastax-ssl-training 0 fixed-scenario6.tar.gz /home/automaton
```

Untar after `ssh`'ing to `node0`:

```
tar -xf fixed-scenario6.tar.gz
```

Adjust the `cassandra.yaml` to point to the new keystore and then restart the node.