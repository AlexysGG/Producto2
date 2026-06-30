// Program.cs
// Compilar/ejecutar: dotnet run
// URL: http://localhost:8000/?n=10  ->  diez
//
// 1. Consume el servicio web SOAP para obtener el número en inglés
// 2. Traduce al ESPAÑOL usando MyMemory API (gratuita, sin API key)
//
// Sin paquetes NuGet adicionales — solo HttpClient y System.Xml.Linq (.NET base)

using System.Text;
using System.Xml.Linq;

const string SOAP_URL = "https://www.dataaccess.com/webservicesserver/NumberConversion.wso";
const string TRANSLATE_URL = "https://api.mymemory.translated.net/get";
const int PORT = 8000;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls($"http://localhost:{PORT}");
var app = builder.Build();

// ── SOAP ────────────────────────────────────────────────────────────────────

static string BuildEnvelope(long numero) => $"""
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <NumberToWords xmlns="http://www.dataaccess.com/webservicesserver/">
      <ubiNum>{numero}</ubiNum>
    </NumberToWords>
  </soap:Body>
</soap:Envelope>
""";

static XElement? FindElementByLocalName(XElement node, string target)
{
    foreach (var child in node.Elements())
    {
        if (child.Name.LocalName == target) return child;
        var found = FindElementByLocalName(child, target);
        if (found != null) return found;
    }
    return null;
}

static async Task<string> NumberToWordsAsync(HttpClient client, long numero)
{
    var envelope = BuildEnvelope(numero);
    var content = new StringContent(envelope, Encoding.UTF8, "text/xml");
    content.Headers.Add("SOAPAction", "http://www.dataaccess.com/webservicesserver/NumberToWords");

    var response = await client.PostAsync(SOAP_URL, content);
    response.EnsureSuccessStatusCode();

    var xmlText = await response.Content.ReadAsStringAsync();
    var doc = XDocument.Parse(xmlText);

    if (doc.Root == null)
        throw new Exception("No se pudo parsear el XML de respuesta SOAP");

    var result = FindElementByLocalName(doc.Root, "NumberToWordsResult");

    if (result == null || string.IsNullOrEmpty(result.Value))
        throw new Exception("No se encontró NumberToWordsResult en la respuesta SOAP");

    return result.Value;
}

// ── Traducción (MyMemory API) ──────────────────────────────────────────────

static async Task<string> TranslateToSpanishAsync(HttpClient client, string texto)
{
    // Uri.EscapeDataString codifica correctamente el | como %7C
    var qEncoded = Uri.EscapeDataString(texto);
    var langpairEncoded = Uri.EscapeDataString("en|es"); // -> en%7Ces

    var url = $"{TRANSLATE_URL}?q={qEncoded}&langpair={langpairEncoded}";

    var response = await client.GetAsync(url);
    response.EnsureSuccessStatusCode();

    var json = await response.Content.ReadAsStringAsync();

    // Extraer "translatedText" del JSON sin librería externa
    // Respuesta: {"responseData":{"translatedText":"diez",...},...}
    const string key = "\"translatedText\":\"";
    int start = json.IndexOf(key, StringComparison.Ordinal);
    if (start == -1)
        throw new Exception($"No se encontró translatedText en: {json}");

    start += key.Length;
    int end = json.IndexOf('"', start);
    return json.Substring(start, end - start);
}

// ── Endpoint ────────────────────────────────────────────────────────────────

app.MapGet("/", async (HttpContext ctx) =>
{
    var nParam = ctx.Request.Query["n"].ToString();

    if (string.IsNullOrEmpty(nParam) || !long.TryParse(nParam, out long numero))
    {
        ctx.Response.StatusCode = 400;
        ctx.Response.ContentType = "text/plain; charset=utf-8";
        await ctx.Response.WriteAsync("Uso: /?n=<numero>   Ejemplo: /?n=10");
        return;
    }

    try
    {
        using var client = new HttpClient();
        client.Timeout = TimeSpan.FromSeconds(15);

        var enIngles = await NumberToWordsAsync(client, numero);
        var enEspanol = await TranslateToSpanishAsync(client, enIngles);

        ctx.Response.StatusCode = 200;
        ctx.Response.ContentType = "text/plain; charset=utf-8";
        await ctx.Response.WriteAsync(enEspanol);
    }
    catch (Exception ex)
    {
        ctx.Response.StatusCode = 500;
        ctx.Response.ContentType = "text/plain; charset=utf-8";
        await ctx.Response.WriteAsync($"Error: {ex.Message}");
    }
});

Console.WriteLine($"[clisoap2] Servidor corriendo en http://localhost:{PORT}");
Console.WriteLine($"Prueba: http://localhost:{PORT}/?n=10");

app.Run();