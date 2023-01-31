import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLServerSocket;
import javax.net.ssl.SSLServerSocketFactory;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.TrustManagerFactory;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.Provider;
import java.security.Security;
import java.security.cert.X509Certificate;

public class Server {
    public static void main(String[] args) throws Exception {
        System.out.println("Initializing SunPKCS11 Provider...");
        final String keystorePassword = "test123";
        final Path nssConfigPath = Path.of("./server/pkcs11.cfg");
        //final Path nssConfigPath = Path.of("./server/pkcs11_softhsm.cfg");
        final Provider uninit_Provider = Security.getProvider("SunPKCS11");
        final Provider provider = uninit_Provider.configure(nssConfigPath.toString());
        Security.addProvider(provider);

        final KeyStore keystore = KeyStore.getInstance("PKCS11", provider);
        keystore.load(null, keystorePassword.toCharArray());


        final KeyManagerFactory kmf = KeyManagerFactory.getInstance("PKIX");
        kmf.init(keystore, keystorePassword.toCharArray());
        final TrustManagerFactory tmf = TrustManagerFactory.getInstance("PKIX");
        tmf.init(keystore);

        final SSLContext sslContext = SSLContext.getInstance("TLSv1.3");
        sslContext.init(kmf.getKeyManagers(), tmf.getTrustManagers(), null);

        // Use the SSL context to create an SSLServerSocketFactory
        SSLServerSocketFactory sslServerSocketFactory = sslContext.getServerSocketFactory();

        // Create an SSLServerSocket that listens on port 8443
        SSLServerSocket sslServerSocket = (SSLServerSocket) sslServerSocketFactory.createServerSocket(8443);

        // Configure the SSLServerSocket to require client authentication
        sslServerSocket.setNeedClientAuth(true);

        // Start listening for incoming connections
        while (true) {
            System.out.println("Waiting for client...");
            SSLSocket sslSocket = (SSLSocket) sslServerSocket.accept();
            System.out.println("Starting handshake ...");
            sslSocket.startHandshake();
            System.out.println("Handshare successful");

            // Get the client's certificate chain
            X509Certificate[] clientCertificates = (X509Certificate[]) sslSocket.getSession().getPeerCertificates();
            X509Certificate clientCertificate = clientCertificates[0];

            // Verify the client's certificate
            clientCertificate.checkValidity();
            //  trustStore.getCertificateAlias(clientCertificate) != null
            // additional check on clientCertificate

            InputStream in = sslSocket.getInputStream();
            OutputStream out = sslSocket.getOutputStream();

            // read the incoming request
            BufferedReader reader = new BufferedReader(new InputStreamReader(in));
            String request = reader.readLine();

            // check GET
            if (request != null && request.startsWith("GET")) {
                // Write "HTTP/1.1 200 OK\n" to the client
                out.write("HTTP/1.1 200 OK\n".getBytes());
                out.flush();
                out.write("Content-Type: text/plain\n".getBytes());
                out.flush();
                out.write("Content-Length: 2\n".getBytes());
                out.flush();
                out.write("\n".getBytes());
                out.flush();
                out.write("OK".getBytes());
                out.flush();
            }

            // Close the socket
            sslSocket.close();
        }

    }
}