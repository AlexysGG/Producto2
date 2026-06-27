// CliSoap1.java
// Compilar: javac CliSoap1.java
// Ejecutar: java CliSoap1
// URL:      http://localhost:8000/?n=10  →  ten
//
// Consume el servicio web SOAP público:
//   https://www.dataaccess.com/webservicesserver/NumberConversion.wso?WSDL
// Devuelve el número en palabras en INGLÉS
// Sin dependencias externas — solo JDK 21

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.w3c.dom.Document;
import org.w3c.dom.NodeList;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public class CliSoap1 {

    private static final String SOAP_URL =
            "https://www.dataaccess.com/webservicesserver/NumberConversion.wso";
    private static final int PORT = 8000;

    private static String buildEnvelope(long numero) {
        return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" +
               "<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n" +
               "  <soap:Body>\n" +
               "    <NumberToWords xmlns=\"http://www.dataaccess.com/webservicesserver/\">\n" +
               "      <ubiNum>" + numero + "</ubiNum>\n" +
               "    </NumberToWords>\n" +
               "  </soap:Body>\n" +
               "</soap:Envelope>";
    }

    private static String numberToWords(long numero) throws Exception {
        String envelope = buildEnvelope(numero);

        URL url = new URI(SOAP_URL).toURL();
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setRequestProperty("Content-Type", "text/xml; charset=utf-8");
        conn.setRequestProperty("SOAPAction",
                "http://www.dataaccess.com/webservicesserver/NumberToWords");

        try (OutputStream os = conn.getOutputStream()) {
            os.write(envelope.getBytes(StandardCharsets.UTF_8));
        }

        InputStream is = conn.getResponseCode() < 400
                ? conn.getInputStream() : conn.getErrorStream();

        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        DocumentBuilder builder = factory.newDocumentBuilder();
        Document doc = builder.parse(is);

        // Buscar NumberToWordsResult ignorando el prefijo de namespace
        NodeList nodes = doc.getElementsByTagNameNS("*", "NumberToWordsResult");
        if (nodes.getLength() == 0)
            nodes = doc.getElementsByTagName("NumberToWordsResult");
        if (nodes.getLength() == 0)
            throw new RuntimeException("No se encontró NumberToWordsResult en la respuesta SOAP");

        return nodes.item(0).getTextContent().trim();
    }

    private static String getParam(String query, String name) {
        if (query == null) return null;
        for (String part : query.split("&")) {
            String[] kv = part.split("=", 2);
            if (kv.length == 2 && kv[0].equals(name)) return kv[1];
        }
        return null;
    }

    private static void sendResponse(HttpExchange ex, int status, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().set("Content-Type", "text/plain; charset=utf-8");
        ex.sendResponseHeaders(status, bytes.length);
        try (OutputStream os = ex.getResponseBody()) {
            os.write(bytes);
        }
    }

    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(PORT), 0);

        server.createContext("/", (HttpExchange ex) -> {
            if (ex.getRequestURI().getPath().equals("/favicon.ico")) {
                ex.sendResponseHeaders(204, -1);
                ex.close();
                return;
            }

            String nParam = getParam(ex.getRequestURI().getQuery(), "n");

            if (nParam == null || !nParam.matches("-?\\d+")) {
                sendResponse(ex, 400, "Uso: /?n=<numero>   Ejemplo: /?n=10");
                return;
            }

            int status;
            String body;
            try {
                body = numberToWords(Long.parseLong(nParam));
                status = 200;
            } catch (Exception e) {
                body = "Error al llamar al servicio SOAP: " + e.getMessage();
                status = 500;
            }

            sendResponse(ex, status, body);
        });

        server.start();
        System.out.println("[CliSoap1] Servidor corriendo en http://localhost:" + PORT);
        System.out.println("Prueba: http://localhost:" + PORT + "/?n=10");
    }
}