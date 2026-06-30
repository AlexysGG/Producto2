// Program.cs
// Compilar/ejecutar: dotnet run
// URL: http://localhost:8000/?n=10  ->  ten
//
// Consume el servicio web SOAP público:
//   https://www.dataaccess.com/webservicesserver/NumberConversion.wso?WSDL
// Devuelve el número en palabras en INGLÉS
//
// Sin paquetes NuGet adicionales — solo HttpClient y System.Xml.Linq (.NET base)

using System.Text;
using System.Xml.Linq;

const string SOAP_URL = "https://www.dataaccess.com/webservicesserver/NumberConversion.wso";
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

// Busca recursivamente un elemento por nombre local, ignorando namespace
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

static async Task<string> NumberToWordsAsync(long numero)
{
    using var client = new HttpClient();
    client.Timeout = TimeSpan.FromSeconds(15);

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
        var palabras = await NumberToWordsAsync(numero);
        ctx.Response.StatusCode = 200;
        ctx.Response.ContentType = "text/plain; charset=utf-8";
        await ctx.Response.WriteAsync(palabras);
    }
    catch (Exception ex)
    {
        ctx.Response.StatusCode = 500;
        ctx.Response.ContentType = "text/plain; charset=utf-8";
        await ctx.Response.WriteAsync($"Error al llamar al servicio SOAP: {ex.Message}");
    }
});

Console.WriteLine($"[clisoap1] Servidor corriendo en http://localhost:{PORT}");
Console.WriteLine($"Prueba: http://localhost:{PORT}/?n=10");

app.Run();