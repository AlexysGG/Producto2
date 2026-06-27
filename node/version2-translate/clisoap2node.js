// node clisoap2.js
// http://localhost:8000/?n=10  →  diez

const http = require("http");
const axios = require("axios");
const xml2js = require("xml2js");
const { translate } = require("@vitalets/google-translate-api");

const WSDL_URL = "https://www.dataaccess.com/webservicesserver/NumberConversion.wso";
const PORT = 8000;

function buildSoapEnvelope(numero) {
  return `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <NumberToWords xmlns="http://www.dataaccess.com/webservicesserver/">
      <ubiNum>${numero}</ubiNum>
    </NumberToWords>
  </soap:Body>
</soap:Envelope>`;
}

// Busca recursivamente una clave ignorando el prefijo de namespace (ej. "m:Algo" → "Algo")
function findValue(obj, keyName) {
  if (typeof obj !== "object" || obj === null) return null;
  for (const key of Object.keys(obj)) {
    const localName = key.includes(":") ? key.split(":").pop() : key;
    if (localName === keyName) return obj[key];
    const found = findValue(obj[key], keyName);
    if (found !== null) return found;
  }
  return null;
}

async function numberToWords(numero) {
  const envelope = buildSoapEnvelope(numero);
  const response = await axios.post(WSDL_URL, envelope, {
    headers: {
      "Content-Type": "text/xml; charset=utf-8",
      SOAPAction: "http://www.dataaccess.com/webservicesserver/NumberToWords",
    },
  });

  const parsed = await xml2js.parseStringPromise(response.data, {
    explicitArray: false,
    ignoreAttrs: true,
  });

  const resultado = findValue(parsed, "NumberToWordsResult");
  if (resultado === null) {
    throw new Error("No se encontró NumberToWordsResult en la respuesta");
  }
  return String(resultado);
}

async function translateToSpanish(texto) {
  const { text } = await translate(texto, { from: "en", to: "es" });
  return text;
}

// ---------- Servidor HTTP ----------
const server = http.createServer(async (req, res) => {
  if (req.url === "/favicon.ico") {
    res.writeHead(204);
    res.end();
    return;
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);
  const n = url.searchParams.get("n");

  if (!n || isNaN(Number(n))) {
    res.writeHead(400, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Uso: /?n=<numero>   Ejemplo: /?n=10");
    return;
  }

  let status = 200;
  let body = "";

  try {
    const enIngles = await numberToWords(Number(n));
    body = await translateToSpanish(enIngles);
  } catch (err) {
    status = 500;
    body = `Error: ${err.message}`;
  }

  res.writeHead(status, { "Content-Type": "text/plain; charset=utf-8" });
  res.end(body);
});

server.listen(PORT, () => {
  console.log(`[clisoap2] Servidor corriendo en http://localhost:${PORT}`);
  console.log(`Prueba: http://localhost:${PORT}/?n=10`);
});