# PKCS11+nss TLS mutual authentication

## Issue:
The SunPKCS11 module introduced a [change][1] where it attempts to verify that the digest signature is available 
as mechanism from the PKCS11 provider. In case of NSS, it doesn't return `CKM_SHA256` as an available mechanism, 
hence the certificate verification fails in Java 17. The same code works in Java 11.

SoftHSM does return CKM_SHA256 as available mechanism, hence the same code works when connecting to SoftHSM via PKCS11 in Java 17.

## Pre-req
- Need `docker compose`

## Run TLS enabled Server that uses PKCS11+nss via docker compose
- To run sample Server (on port 8443) using Java 17 (and generating various certificates, keystores on first run), run following command:
```
docker compose up
```

- To run sample Server (on port 8443) using Java 11 instead (and generating various certificates, keystores on first run), run following command:
```
docker compose -f ./docker-compose-java11.yml up
```
## Client connecting to Server
- From a different terminal windows, use `curl` to connect to above server:
```
curl --cacert ./certs/client.pem --cert-type P12 --cert ./certs/client.p12:test123 https://localhost:8443/`
```

## Expected Result:
The connection to server should be established without any problems.

## Java 17 behavior:

Server side:
~~~
...
pkcs11-server     | javax.net.ssl|DEBUG|10|main|2023-06-22 09:51:41.556 GMT|null:-1|close the SSL connection (passive)
pkcs11-server     | Exception in thread "main" javax.net.ssl.SSLException: No supported CertificateVerify signature algorithm for RSA  key
pkcs11-server     | 	at java.base/sun.security.ssl.Alert.createSSLException(Unknown Source)
pkcs11-server     | 	at java.base/sun.security.ssl.Alert.createSSLException(Unknown Source)
pkcs11-server     | 	at java.base/sun.security.ssl.TransportContext.fatal(Unknown Source)
pkcs11-server     | 	at java.base/sun.security.ssl.TransportContext.fatal(Unknown Source)
pkcs11-server     | 	at java.base/sun.security.ssl.TransportContext.fatal(Unknown Source)
pkcs11-server     | 	at java.base/sun.security.ssl.CertificateVerify$T13CertificateVerifyMessage.<init>(Unknown Source)
...
~~~

## Java 11 behavior:
No exception is reported on server side, `curl` prints `OK`.

## Server with PKCS11+SoftHSM (Java 17)
```
docker compose -f ./docker-compose-softhsm.yml up
```
No exception is reported on server side, `curl` prints `OK`.


---
[1]: https://github.com/openjdk/jdk17u/blob/2fe42855c48c49b515b97312ce64a5a8ef3af407/src/jdk.crypto.cryptoki/share/classes/sun/security/pkcs11/P11PSSSignature.java#L425-L428