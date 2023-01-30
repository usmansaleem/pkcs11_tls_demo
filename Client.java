import java.net.*;
import java.io.*;
import javax.net.ssl.*;
import javax.security.cert.X509Certificate;
import java.security.KeyStore;


public class Client {

    public static void main(String[] args) throws Exception {
        String host = "localhost";
        int port = 8443;

        SSLSocketFactory factory = null;
        SSLContext ctx;
        KeyManagerFactory kmf;
        TrustManagerFactory tmf;
        KeyStore ks;
        KeyStore ts;
        char[] passphrase = "test123".toCharArray();

        ctx = SSLContext.getInstance("TLSv1.3");
        kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
        tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        ks = KeyStore.getInstance("PKCS12");
        ts = KeyStore.getInstance("PKCS12");

        //load keystore
        ks.load(new FileInputStream("./client/client.p12"), passphrase);
        //load truststore
        ts.load(new FileInputStream("./ca_certs/truststore.p12"), passphrase);

        kmf.init(ks, passphrase);
        tmf.init(ts);
        
        ctx.init(kmf.getKeyManagers(), tmf.getTrustManagers(), null);

        factory = ctx.getSocketFactory();

        // connect to host
        SSLSocket socket = (SSLSocket)factory.createSocket(host, port);
        socket.startHandshake();

        PrintWriter out = new PrintWriter(
                                  new BufferedWriter(
                                  new OutputStreamWriter(
                                  socket.getOutputStream())));
                                
        out.println("GET / HTTP/1.0");
        out.println();
        out.flush();

        /*
         * Make sure there were no surprises
         */
         if (out.checkError()) {
           System.out.println( "Client: java.io.PrintWriter error");
         }

         /* read response */
         BufferedReader in = new BufferedReader(
                                    new InputStreamReader(
                                    socket.getInputStream()));

         String inputLine;

         while ((inputLine = in.readLine()) != null) {
             System.out.println(inputLine);
         }

         in.close();
         out.close();
         socket.close();
        
    }
    
}