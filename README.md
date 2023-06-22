# PKCS11+nss TLS mutual authentication

## Issue:
The SunPKCS11 module introduced a [change][1] where it attempts to verify that the digest signature is available 
as mechanism from the PKCS11 provider. In case of NSS, it doesn't return `CKM_SHA256` as an available mechanism, 
hence the certificate verification fails in Java 17. The same code works in Java 11.

SoftHSM does return CKM_SHA256 as available mechanism, hence the same code works when connecting to SoftHSM via PKCS11 in Java 17.

## Pre-req
- Need `docker compose`

## Run
- `docker compose up` This will generate CA, server and client certificates in first run and execute sample Server.
This will expose server on port 8443.
- From a different terminal windows, use `curl` to connect to above server:
```
curl --cacert ./certs/client.pem --cert-type P12 --cert ./certs/client.p12:test123 https://localhost:8443/`
```

## Expected Result:
The connection to server should be established without any problems.

## Java 17 behavior:

Server side:
~~~
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
No exception is reported on server side, client prints OK.

---
# Setup

## nss setup (Ubuntu)
sudo apt install libnss3-tools

## nss setup (Mac OS)
~~~
brew install nss

ln -s /opt/homebrew/lib/libsoftokn3.dylib ./libsoftokn3.dylib
ln -s /opt/homebrew/lib/libnss3.dylib ./libnss3.dylib
~~~
The `certs.sh` will create the PKCS11+nss configuration file in `server`.

## SoftHSM setup - optional (Mac OS)
(Assuming `certs.sh` has already been executed.)

Install softhsm and opensc via brew
`brew install softhsm`
`brew install --cask opensc`

Initialize token
~~~
softhsm2-util --init-token --free --label "testtoken" --pin test123 --so-pin test123
softhsm2-util --show-slots
~~~

Take a note of the reassigned slot number and change it in the cfg file and subsequent
commands accordingly. In my example, the slot is `284238276`.

Create file pkcs11_softhsm.cfg
~~~
cat <<EOF >./server/pkcs11_softhsm.cfg
name = Softhsm-compa-server
library = /opt/homebrew/Cellar/softhsm/2.6.1/lib/softhsm/libsofthsm2.so
slot = 284238276
showInfo = true
EOF
~~~

Import server.p12 keystore into Softhsm
~~~
p11tool --provider /opt/homebrew/Cellar/softhsm/2.6.1/lib/softhsm/libsofthsm2.so \
--label "root_ca" --so-login --set-so-pin test123 \
--write --mark-ca --mark-trusted --load-certificate ./ca_certs/root_ca.pem pkcs11:token=testtoken

p11tool --provider /opt/homebrew/Cellar/softhsm/2.6.1/lib/softhsm/libsofthsm2.so \
--label "interca_ca" --so-login --set-so-pin test123 \
--write --mark-ca --mark-trusted --load-certificate ./ca_certs/inter_ca.pem pkcs11:token=testtoken

p11tool --provider /opt/homebrew/Cellar/softhsm/2.6.1/lib/softhsm/libsofthsm2.so \
--label "compa_ca" --so-login --set-so-pin test123 \
--write --mark-ca --mark-trusted --load-certificate ./ca_certs/compa_ca.pem pkcs11:token=testtoken

keytool -importkeystore -srckeystore ./server/server.p12 -srcstoretype PKCS12 \
-srcstorepass test123 -srckeypass test123 -srcalias server \
-destkeystore NONE -deststoretype PKCS11 \
-providerClass sun.security.pkcs11.SunPKCS11 -providerArg ./server/pkcs11_softhsm.cfg \
-deststorepass test123 -destalias server \
-noprompt 


~~~

Verify
~~~
keytool -list -v -keystore NONE -storepass test123 -storetype PKCS11 \
-providerClass sun.security.pkcs11.SunPKCS11 -providerArg ./server/pkcs11_softhsm.cfg
~~~

---
[1]: https://github.com/openjdk/jdk17u/blob/2fe42855c48c49b515b97312ce64a5a8ef3af407/src/jdk.crypto.cryptoki/share/classes/sun/security/pkcs11/P11PSSSignature.java#L425-L428