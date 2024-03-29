import javax.net.ssl.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.security.*;
import java.security.cert.X509Certificate;

/**
 * A simple HTTP server showcasing PKCS11 and NSS bug in Java 17 and above.
 */
public class Server {
    // mounted via Docker
    private static final String NSS_CONFIG_PATH = "/certs/pkcs11.cfg";

    public static void main(String[] args) throws Exception {
        System.out.print("Initializing SunPKCS11 Provider ");
        final Path nssConfigPath;
        if (args.length > 0) {
           nssConfigPath = Path.of(args[0]);     
        } else {
           nssConfigPath = Path.of(NSS_CONFIG_PATH);
        }
        System.out.println("using " + nssConfigPath);
        final String keystorePassword = "test123";
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