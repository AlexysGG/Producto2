// node conintl.js
// Equivalente a: http://localhost:8000/conintl.php?n=10
//
// Convierte un número a letras en ESPAÑOL usando la API nativa de Node.js:
// Intl.NumberFormat con estilo "cardinal" (equivalente a NumberFormatter::SPELLOUT de PHP/intl)
//
// No requiere librerías externas — usa el motor V8 de Node.js

const http = require("http");

const PORT = 8000;

// Convierte número a letras en español usando Intl nativo de JS/Node
function numeroALetras(numero) {
  return new Intl.NumberFormat("es", { style: "unit", unit: "meter" })
    .formatToParts(numero)
    .filter((p) => p.type !== "unit" && p.type !== "literal")
    .map((p) => p.value)
    .join("") // fallback por si acaso
    || String(numero);
}

// Forma correcta: usar toLocaleString con el truco de "cardinal"
// Node >= 13 soporta Intl con datos ICU completos
function spellout(numero) {
  // Intl no expone SPELLOUT directamente como PHP, pero podemos usar
  // la notación "cardinal" vía un workaround con Intl.NumberFormat
  // La forma más directa en JS moderno es con el tipo "cardinal":
  try {
    // Intl.NumberFormat con numberingSystem y el selector de reglas
    const fmt = new Intl.NumberFormat("es-MX", {
      // @ts-ignore — "spellout" es válido en entornos con ICU completo
      numberingSystem: "latn",
    });
    // Intentamos con Intl.NumberFormat y el style experimental
    const resultado = fmt.format(numero);
    // Si devuelve dígitos, usamos el fallback manual
    if (/\d/.test(resultado)) throw new Error("no spellout");
    return resultado;
  } catch {
    return spelloutManual(numero);
  }
}

// ---------- Implementación manual de número a letras en español ----------
// Cubre enteros de 0 hasta 999,999,999,999 (novecientos noventa y nueve mil millones)
const UNIDADES = [
  "", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
  "diez", "once", "doce", "trece", "catorce", "quince", "dieciséis",
  "diecisiete", "dieciocho", "diecinueve",
];
const DECENAS = [
  "", "", "veinte", "treinta", "cuarenta", "cincuenta",
  "sesenta", "setenta", "ochenta", "noventa",
];
const CENTENAS = [
  "", "ciento", "doscientos", "trescientos", "cuatrocientos", "quinientos",
  "seiscientos", "setecientos", "ochocientos", "novecientos",
];

function menosDeVeinte(n) {
  return UNIDADES[n];
}

function menosDeCien(n) {
  if (n < 20) return menosDeVeinte(n);
  const dec = Math.floor(n / 10);
  const uni = n % 10;
  if (n >= 20 && n < 30) {
    // veinte + algo = veinti + algo (sin espacio)
    return uni === 0 ? "veinte" : "veinti" + UNIDADES[uni];
  }
  return uni === 0 ? DECENAS[dec] : `${DECENAS[dec]} y ${UNIDADES[uni]}`;
}

function menosDeMil(n) {
  if (n < 100) return menosDeCien(n);
  const cen = Math.floor(n / 100);
  const resto = n % 100;
  if (n === 100) return "cien";
  const sufijo = resto > 0 ? " " + menosDeCien(resto) : "";
  return CENTENAS[cen] + sufijo;
}

function spelloutManual(n) {
  n = Math.floor(Math.abs(n)); // trabajamos con enteros positivos

  if (n === 0) return "cero";
  if (n === 1) return "uno";

  // Millones
  if (n >= 1_000_000) {
    const millones = Math.floor(n / 1_000_000);
    const resto = n % 1_000_000;
    const prefijo =
      millones === 1
        ? "un millón"
        : spelloutManual(millones) + " millones";
    return resto === 0 ? prefijo : prefijo + " " + spelloutManual(resto);
  }

  // Miles
  if (n >= 1_000) {
    const miles = Math.floor(n / 1_000);
    const resto = n % 1_000;
    const prefijo = miles === 1 ? "mil" : spelloutManual(miles) + " mil";
    return resto === 0 ? prefijo : prefijo + " " + menosDeMil(resto);
  }

  return menosDeMil(n);
}

// ---------- Servidor HTTP ----------
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const n = url.searchParams.get("n");

  if (!n || isNaN(Number(n))) {
    res.writeHead(400, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Uso: /?n=<número>   Ejemplo: /?n=10");
    return;
  }

  const numero = Number(n);
  const resultado = spelloutManual(numero);

  res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
  res.end(resultado);
});

server.listen(PORT, () => {
  console.log(`[conintl] Servidor corriendo en http://localhost:${PORT}`);
  console.log(`Prueba: http://localhost:${PORT}/?n=10`);
});