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

