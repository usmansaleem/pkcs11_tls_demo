#! /bin/sh

# init softhsm token and create the configuration file
mkdir -p /config

if [ -f /config/pkcs11_softhsm.cfg ]; then
  echo '/config/pkcs11_softhsm.cfg already exists'
else
OUTPUT=$(softhsm2-util --init-token --slot 0 --label "testtoken" --pin test123 --so-pin test123)
SLOT=$(echo $OUTPUT | rev | cut -d " " -f1 | rev)

cat <<EOF >/config/pkcs11_softhsm.cfg
name = Softhsm-mycompany-server
library = /usr/lib/softhsm/libsofthsm2.so
slot = $SLOT
showInfo = true
EOF

cat /config/pkcs11_softhsm.cfg

echo "*******************************"
echo "Importing trusted CA in softhsm"
echo "*******************************"
p11tool --provider /usr/lib/softhsm/libsofthsm2.so \
--label "root_ca" --so-login --set-so-pin test123 \
--write --mark-ca --mark-trusted --load-certificate /certs/root.pem pkcs11:token=testtoken

p11tool --provider /usr/lib/softhsm/libsofthsm2.so \
--label "interca_ca" --so-login --set-so-pin test123 \
--write --mark-ca --mark-trusted --load-certificate /certs/inter.pem pkcs11:token=testtoken

p11tool --provider /usr/lib/softhsm/libsofthsm2.so \
--label "mycompany_ca" --so-login --set-so-pin test123 \
--write --mark-ca --mark-trusted --load-certificate /certs/mycompany.pem pkcs11:token=testtoken

echo "****************************************"
echo "Importing server private key in softhsm"
echo "****************************************"
keytool -importkeystore -srckeystore /certs/server.p12 -srcstoretype PKCS12 \
-srcstorepass test123 -srckeypass test123 -srcalias server \
-destkeystore NONE -deststoretype PKCS11 \
-providerClass sun.security.pkcs11.SunPKCS11 -providerArg /config/pkcs11_softhsm.cfg \
-deststorepass test123 -destalias server \
-noprompt 

fi




java -Djavax.net.debug=ssl:handshake:verbose Server.java /config/pkcs11_softhsm.cfg