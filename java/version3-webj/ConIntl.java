// ConIntl.java
// Compilar: javac -encoding UTF-8 ConIntl.java
// Ejecutar: java ConIntl
// URL:      http://localhost:8000/?n=10  →  diez
//
// Convierte un número a letras en ESPAÑOL.
// Implementación propia sin librerías externas.
// Equivalente a: new NumberFormatter("es", NumberFormatter::SPELLOUT) de PHP
// Sin dependencias externas — solo JDK 21

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

public class ConIntl {

    private static final int PORT = 8000;

    // ── Tablas de conversión ──────────────────────────────────────────────────

    private static final String[] UNIDADES = {
        "", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
        "diez", "once", "doce", "trece", "catorce", "quince",
        "dieciséis", "diecisiete", "dieciocho", "diecinueve"
    };

    private static final String[] DECENAS = {
        "", "", "veinte", "treinta", "cuarenta", "cincuenta",
        "sesenta", "setenta", "ochenta", "noventa"
    };

    // "ciento" para 101-199; exactamente 100 se maneja aparte como "cien"
    private static final String[] CENTENAS = {
        "", "ciento", "doscientos", "trescientos", "cuatrocientos", "quinientos",
        "seiscientos", "setecientos", "ochocientos", "novecientos"
    };

    // ── Lógica de conversión ──────────────────────────────────────────────────

    private static String menosDeCien(long n) {
        if (n < 20) return UNIDADES[(int) n];
        long dec = n / 10, uni = n % 10;
        if (n < 30)  // 20-29: veinti + algo
            return uni == 0 ? "veinte" : "veinti" + UNIDADES[(int) uni];
        return uni == 0 ? DECENAS[(int) dec] : DECENAS[(int) dec] + " y " + UNIDADES[(int) uni];
    }

    private static String menosDeMil(long n) {
        if (n < 100) return menosDeCien(n);
        if (n == 100) return "cien";
        long cen = n / 100, resto = n % 100;
        return CENTENAS[(int) cen] + (resto > 0 ? " " + menosDeCien(resto) : "");
    }

    public static String spellout(long n) {
        if (n == 0)  return "cero";
        if (n < 0)   return "menos " + spellout(-n);
        if (n == 1)  return "uno";

        // Billones (10^12)
        if (n >= 1_000_000_000_000L) {
            long bill = n / 1_000_000_000_000L, resto = n % 1_000_000_000_000L;
            String prefix = bill == 1 ? "un billón" : spellout(bill) + " billones";
            return resto == 0 ? prefix : prefix + " " + spellout(resto);
        }
        // Millones
        if (n >= 1_000_000L) {
            long mill = n / 1_000_000L, resto = n % 1_000_000L;
            String prefix = mill == 1 ? "un millón" : spellout(mill) + " millones";
            return resto == 0 ? prefix : prefix + " " + spellout(resto);
        }
        // Miles
        if (n >= 1_000L) {
            long miles = n / 1_000L, resto = n % 1_000L;
            String prefix = miles == 1 ? "mil" : spellout(miles) + " mil";
            return resto == 0 ? prefix : prefix + " " + menosDeMil(resto);
        }

        return menosDeMil(n);
    }

    // ── Utilidades HTTP ───────────────────────────────────────────────────────

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

    // ── Main ──────────────────────────────────────────────────────────────────

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
                body = spellout(Long.parseLong(nParam));
                status = 200;
            } catch (Exception e) {
                body = "Error: " + e.getMessage();
                status = 500;
            }

            sendResponse(ex, status, body);
        });

        server.start();
        System.out.println("[ConIntl] Servidor corriendo en http://localhost:" + PORT);
        System.out.println("Prueba: http://localhost:" + PORT + "/?n=10");
    }
}