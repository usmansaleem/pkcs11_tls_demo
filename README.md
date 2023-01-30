## PKCS11+nss TLS mutual authentication

Problem: The PKCS11+nss backed TLS mutual authentication seems to be broken in Java 17 when dealing with RSA keys.
The same code works in Java 11.

See `certs.sh` which creates CA, server and client keystores and initialize the nss database for the server.
See `Server.java` which creates a simple HelloWorld `SSLServerSocket` backed by PKCS11 keystore.

Execute `java -Djavax.net.debug=ssl:handshake:verbose Server.java`

Expected Result:
The connection to server should be established without any problems.
`curl --cacert ./client/client.pem --cert-type P12 --cert ./client/client.p12:test123 https://localhost:8443/`

Java 17 behavior:

Server side:
~~~
Exception in thread "main" javax.net.ssl.SSLException: No supported CertificateVerify signature algorithm for RSA  key
at java.base/sun.security.ssl.Alert.createSSLException(Alert.java:133)
at java.base/sun.security.ssl.Alert.createSSLException(Alert.java:117)
...
~~~

Java 11 behavior:
No exception is reported on server side, and curl returns OK.

---

## nss setup (Mac OS)
~~~
brew install nss

ln -s /opt/homebrew/lib/libsoftokn3.dylib ./libsoftokn3.dylib
ln -s /opt/homebrew/lib/libnss3.dylib ./libnss3.dylib
~~~
The `certs.sh` will create the PKCS11+nss configuration file in `server`.

## SoftHSM setup (Mac OS)
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


