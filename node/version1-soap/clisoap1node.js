// node clisoap1.js
// http://localhost:8000/?n=10  →  ten

const http = require("http");
const axios = require("axios");
const xml2js = require("xml2js");

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

async function numberToWords(numero) {
  const envelope = buildSoapEnvelope(numero);
  const response = await axios.post(WSDL_URL, envelope, {
    headers: {
      "Content-Type": "text/xml; charset=utf-8",
      SOAPAction: "http://www.dataaccess.com/webservicesserver/NumberToWords",
    },
  });

  // Parsear el XML de respuesta
  const parsed = await xml2js.parseStringPromise(response.data, {
    explicitArray: false,
    ignoreAttrs: true,
  });

  // La respuesta SOAP tiene esta estructura:
  // parsed["soap:Envelope"]["soap:Body"]["m:NumberToWordsResponse"]["m:NumberToWordsResult"]
  // Pero los prefijos de namespace pueden variar, así que buscamos recursivamente
  const resultado = findValue(parsed, "NumberToWordsResult");
  if (resultado === null) {
    throw new Error("No se encontró NumberToWordsResult en la respuesta:\n" + JSON.stringify(parsed, null, 2));
  }
  return String(resultado);
}

// Busca recursivamente una clave que TERMINE en el nombre dado (ignora prefijo de namespace)
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
    body = await numberToWords(Number(n));
  } catch (err) {
    status = 500;
    body = `Error: ${err.message}`;
  }

  res.writeHead(status, { "Content-Type": "text/plain; charset=utf-8" });
  res.end(body);
});

server.listen(PORT, () => {
  console.log(`[clisoap1] Servidor corriendo en http://localhost:${PORT}`);
  console.log(`Prueba: http://localhost:${PORT}/?n=10`);
});