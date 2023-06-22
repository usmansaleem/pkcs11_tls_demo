#! /bin/sh

# Generate root CA, inter CA, mycompany CA certificates and keystores
# Server and client certificate signed by mycompany CA
# NSS database for server certificate

set -e

if [ -f /certs/root.pem ]; then
  echo 'SSL certificates already exists'
  exit 0
fi

echo "*************************************"
echo "Generating CA certificates keystores"
echo "*************************************"

echo "Generating root ca keypair"
keytool -genkeypair -alias root_ca -dname "CN=root.ca" -ext bc:c -keyalg RSA -keysize 4096 \
-sigalg SHA256WithRSA -validity 36500 \
-storepass test123 \
-keystore /certs/root.p12

echo "Generating inter ca keypair"
keytool -genkeypair -alias inter_ca -dname "CN=inter.ca" \
-ext bc:c=ca:true,pathlen:1 -ext ku:c=dS,kCS,cRLs \
-keyalg RSA -keysize 4096 -sigalg SHA256WithRSA -validity 36500 \
-storepass test123 \
-keystore /certs/inter.p12

echo "Generating company ca keypair: mycompany"
keytool -genkeypair -alias mycompany_ca -dname "CN=mycompany.ca" \
-ext bc:c=ca:true,pathlen:0 -ext ku:c=dS,kCS,cRLs \
-keyalg RSA -keysize 4096 -sigalg SHA256WithRSA -validity 36500 \
-storepass test123 \
-keystore /certs/mycompany.p12

echo "Export Root certificate in PEM format"
keytool -storepass test123 -keystore /certs/root.p12 -alias root_ca -exportcert -rfc > /certs/root.pem

echo "*******************************************"
echo "Generating and signing CA CSR certificates"
echo "*******************************************"

echo "Generating inter ca CSR and signing it with root_ca"
keytool -storepass test123 -keystore /certs/inter.p12 -certreq -alias inter_ca \
| keytool -storepass test123 -keystore /certs/root.p12 -gencert -alias root_ca \
-ext bc:c=ca:true,pathlen:1 -ext ku:c=dS,kCS,cRLs -rfc > /certs/inter.pem

echo "Combine root PEM to inter PEM"
cat /certs/root.pem >> /certs/inter.pem

echo "Importing signed inter ca CSR into keystore /certs/inter.p12"
keytool -keystore /certs/inter.p12 -importcert -alias inter_ca \
-storepass test123 -noprompt -file /certs/inter.pem

echo "Generating mycompany ca CSR and signing it with inter_ca"
keytool -storepass test123 -keystore /certs/mycompany.p12 -certreq -alias mycompany_ca \
| keytool -storepass test123 -keystore /certs/inter.p12 -gencert -alias inter_ca \
-ext bc:c=ca:true,pathlen:0 -ext ku:c=dS,kCS,cRLs -rfc > /certs/mycompany.pem

echo "Combine root PEM to mycompany PEM"
cat /certs/root.pem >> /certs/mycompany.pem

echo "Importing signed mycompany ca CSR into /certs/mycompany.p12"
keytool -keystore /certs/mycompany.p12 -importcert -alias mycompany_ca \
-storepass test123 -noprompt -file /certs/mycompany.pem

echo "***************************************"
echo "Generating CA certificates Truststore"
echo "**************************************"
keytool -import -trustcacerts -alias root_ca \
-file /certs/root.pem -keystore /certs/ca_truststore.p12 \
-storepass test123 -noprompt

keytool -import -trustcacerts -alias interna_ca \
-file /certs/inter.pem -keystore /certs/ca_truststore.p12 \
-storepass test123 -noprompt

keytool -import -trustcacerts -alias mycompany_ca \
-file /certs/mycompany.pem -keystore /certs/ca_truststore.p12 \
-storepass test123 -noprompt

echo "********************************************************"
echo "Generating server and client certificates and keystores"
echo "********************************************************"
for name in server client
do
  echo "Generating keystore for $name"
   keytool -genkeypair -keystore /certs/$name.p12 -storepass test123 -alias $name \
  -keyalg RSA -keysize 2048 -validity 36500 \
  -dname "CN=localhost, OU=mycompany" \
  -ext san=dns:localhost,ip:127.0.0.1
  
  echo "Creating CSR for $name and signing it with mycompany_ca"
  keytool -storepass test123 -keystore /certs/$name.p12 -certreq -alias ${name} \
  | keytool -storepass test123 -keystore /certs/mycompany.p12 -gencert -alias "mycompany_ca" \
  -ext ku:c=dS,nR,kE -ext eku=sA,cA -rfc > "/certs/${name}.pem"
  
  cat /certs/root.pem >> "/certs/${name}.pem"
  
  echo "Importing signed $name CSR into /certs/$name.p12"
  keytool -keystore /certs/$name.p12 -importcert -alias $name \
  -storepass test123 -noprompt -file "/certs/${name}.pem"

# keytool -list -v -storepass test123 -keystore "./${name}/${name}.p12"
done

echo "************************************************"
echo "Generating nss database for server certificates"
echo "************************************************"
NSSDB="/certs/nssdb"
mkdir $NSSDB
echo "test123" > /certs/nsspin.txt

certutil -N -d sql:${NSSDB} -f "/certs/nsspin.txt"
## hack to make Java SunPKCS11 work with new sql version of nssdb
touch ${NSSDB}/secmod.db
echo "Importing certificates from /certs/server.p12 into sql:${NSSDB}"
pk12util -i /certs/server.p12 -d sql:${NSSDB} -k /certs/nsspin.txt -W test123
echo "Fixing truststores in sql:${NSSDB}"
certutil -M -n "CN=root.ca"      -t CT,C,C -d sql:${NSSDB} -f /certs/nsspin.txt
certutil -M -n "CN=inter.ca"     -t CT,C,C -d sql:${NSSDB} -f /certs/nsspin.txt
certutil -M -n "CN=mycompany.ca" -t CT,C,C -d sql:${NSSDB} -f /certs/nsspin.txt

echo "Creating pkcs11 nss config file"
cat <<EOF >/certs/pkcs11.cfg
name = NSScrypto-mycompany-server
nssSecmodDirectory = /certs/nssdb
nssDbMode = readOnly
nssModule = keystore
showInfo = true
EOF
echo "Keystores and nss database created."