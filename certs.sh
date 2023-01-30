#! /bin/sh

names=("server" "client")
#KEY_ALG="EC -groupname secp256r1"
KEY_ALG="RSA -keysize 2048"
OU="compa"
PARENT_PATH=.
##########
CA_CERTS_PATH=./ca_certs
OU_CA_KEYSTORE="${CA_CERTS_PATH}/${OU}_ca.p12"

ROOT_CA_PEM="${CA_CERTS_PATH}/root_ca.pem"
INTER_CA_PEM="${CA_CERTS_PATH}/inter_ca.pem"
COMPA_CA_PEM="${CA_CERTS_PATH}/${OU}_ca.pem"

ROOT_CA_KS=$CA_CERTS_PATH/root_ca.p12
INTER_CA_KS=$CA_CERTS_PATH/inter_ca.p12
COMPA_CA_KS=$CA_CERTS_PATH/compa_ca.p12
TRUSTSTORE_KS=$CA_CERTS_PATH/truststore.p12

mkdir $CA_CERTS_PATH

# CA Certificates
echo "Generating root ca keypair"
keytool -genkeypair -alias root_ca -dname "CN=root.ca" -ext bc:c -keyalg RSA -keysize 4096 \
-sigalg SHA256WithRSA -validity 36500 \
-storepass test123 \
-keystore $ROOT_CA_KS

echo "Generating inter ca keypair"
keytool -genkeypair -alias inter_ca -dname "CN=inter.ca" \
-ext bc:c=ca:true,pathlen:1 -ext ku:c=dS,kCS,cRLs \
-keyalg RSA -keysize 4096 -sigalg SHA256WithRSA -validity 36500 \
-storepass test123 \
-keystore $INTER_CA_KS

echo "Generating company ca keypair: ${OU}"
keytool -genkeypair -alias compa_ca -dname "CN=${OU}.ca" \
-ext bc:c=ca:true,pathlen:0 -ext ku:c=dS,kCS,cRLs \
-keyalg RSA -keysize 4096 -sigalg SHA256WithRSA -validity 36500 \
-storepass test123 \
-keystore $COMPA_CA_KS

keytool -storepass test123 -keystore $ROOT_CA_KS -alias root_ca -exportcert -rfc > $ROOT_CA_PEM

# CSR
echo "Generating inter_ca CSR and signing it with root_ca"
keytool -storepass test123 -keystore $INTER_CA_KS -certreq -alias inter_ca \
| keytool -storepass test123 -keystore $ROOT_CA_KS -gencert -alias root_ca \
-ext bc:c=ca:true,pathlen:1 -ext ku:c=dS,kCS,cRLs -rfc > $INTER_CA_PEM

cat $ROOT_CA_PEM >> $INTER_CA_PEM

echo "Importing signed inter ca CSR into $INTER_CA_KS"
keytool -keystore $INTER_CA_KS -importcert -alias inter_ca \
-storepass test123 -noprompt -file $INTER_CA_PEM

echo "Generating company ca CSR and signing it with inter_ca"
keytool -storepass test123 -keystore $COMPA_CA_KS -certreq -alias ${OU}_ca \
| keytool -storepass test123 -keystore $INTER_CA_KS -gencert -alias inter_ca \
-ext bc:c=ca:true,pathlen:0 -ext ku:c=dS,kCS,cRLs -rfc > $COMPA_CA_PEM

cat $ROOT_CA_PEM >> $COMPA_CA_PEM

echo "Importing signed company ca CSR into $COMPA_CA_KS"
keytool -keystore $COMPA_CA_KS -importcert -alias ${OU}_ca \
-storepass test123 -noprompt -file $COMPA_CA_PEM

echo "Generating Truststore"
keytool -import -trustcacerts -alias root_ca \
-file $ROOT_CA_PEM -keystore $TRUSTSTORE_KS \
-storepass test123 -noprompt

keytool -import -trustcacerts -alias inter_ca \
-file $INTER_CA_PEM -keystore $TRUSTSTORE_KS \
-storepass test123 -noprompt

keytool -import -trustcacerts -alias ${OU}_ca \
-file $COMPA_CA_PEM -keystore $TRUSTSTORE_KS \
-storepass test123 -noprompt

echo "Generating Server and Client keystores..."
### Generate client keystores
for name in "${names[@]}"
do
  CLIENT_PATH="${PARENT_PATH}/${name}"
  KEYSTORE_PATH="${CLIENT_PATH}/${name}.p12"
  NSSDB="${CLIENT_PATH}/nssdb"

  mkdir -p $NSSDB

echo "Generating keystore for $name"
 keytool -genkeypair -keystore $KEYSTORE_PATH -storepass test123 -alias $name \
-keyalg $KEY_ALG -validity 36500 \
-dname "CN=localhost, OU=${OU}" \
-ext san=dns:localhost,ip:127.0.0.1

echo "Creating CSR for $name and signing it with ${OU}_ca"
keytool -storepass test123 -keystore $KEYSTORE_PATH -certreq -alias ${name} \
| keytool -storepass test123 -keystore $OU_CA_KEYSTORE -gencert -alias "${OU}_ca" \
-ext ku:c=dS,nR,kE -ext eku=sA,cA -rfc > "${CLIENT_PATH}/${name}.pem"

cat ${ROOT_CA_PEM} >> "${CLIENT_PATH}/${name}.pem"

echo "Importing signed $name CSR into $KEYSTORE_PATH"
keytool -keystore $KEYSTORE_PATH -importcert -alias $name \
-storepass test123 -noprompt -file "${CLIENT_PATH}/${name}.pem"

# keytool -list -v -storepass test123 -keystore "./${name}/${name}.p12"

echo "Creating empty nss database..."
# create nss database
echo "test123" > ${CLIENT_PATH}/nsspin.txt
certutil -N -d sql:${NSSDB} -f "${CLIENT_PATH}/nsspin.txt"
# hack to make Java SunPKCS11 work with new sql version of nssdb
touch ${NSSDB}/secmod.db

# import certificates in nss database
echo "Importing certificates from $KEYSTORE_PATH into sql:${NSSDB}"
pk12util -i $KEYSTORE_PATH -d sql:${NSSDB} -k ${CLIENT_PATH}/nsspin.txt -W test123
echo "Fixing truststores in sql:${NSSDB}"
certutil -M -n "CN=root.ca"  -t CT,C,C -d sql:${NSSDB} -f ${CLIENT_PATH}/nsspin.txt
certutil -M -n "CN=inter.ca" -t CT,C,C -d sql:${NSSDB} -f ${CLIENT_PATH}/nsspin.txt
certutil -M -n "CN=${OU}.ca" -t CT,C,C -d sql:${NSSDB} -f ${CLIENT_PATH}/nsspin.txt

echo "Creating pkcs11 nss config file"
cat <<EOF >${CLIENT_PATH}/pkcs11.cfg
name = NSScrypto-${OU}-${name}
nssSecmodDirectory = ./${name}/nssdb
nssDbMode = readOnly
nssModule = keystore
showInfo = true
EOF

done
echo "Keystores and nss database created"