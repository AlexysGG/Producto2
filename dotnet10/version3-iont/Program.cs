// Program.cs
// Compilar/ejecutar: dotnet run
// URL: http://localhost:8000/?n=10  ->  diez
//
// Convierte un número a letras en ESPAÑOL.
// Implementación propia, sin librerías de traducción ni SOAP.
// Equivalente a: new NumberFormatter("es", NumberFormatter::SPELLOUT) de PHP
//
// Sin paquetes NuGet adicionales

const int PORT = 8000;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls($"http://localhost:{PORT}");
var app = builder.Build();

// ── Tablas de conversión ────────────────────────────────────────────────────

string[] UNIDADES = {
    "", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
    "diez", "once", "doce", "trece", "catorce", "quince",
    "dieciséis", "diecisiete", "dieciocho", "diecinueve"
};

string[] DECENAS = {
    "", "", "veinte", "treinta", "cuarenta", "cincuenta",
    "sesenta", "setenta", "ochenta", "noventa"
};

// "ciento" para 101-199; exactamente 100 se maneja aparte como "cien"
string[] CENTENAS = {
    "", "ciento", "doscientos", "trescientos", "cuatrocientos", "quinientos",
    "seiscientos", "setecientos", "ochocientos", "novecientos"
};

// ── Lógica de conversión ────────────────────────────────────────────────────

string MenosDeCien(long n)
{
    if (n < 20) return UNIDADES[n];
    long dec = n / 10, uni = n % 10;
    if (n < 30) // 20-29: veinti + algo
        return uni == 0 ? "veinte" : "veinti" + UNIDADES[uni];
    return uni == 0 ? DECENAS[dec] : $"{DECENAS[dec]} y {UNIDADES[uni]}";
}

string MenosDeMil(long n)
{
    if (n < 100) return MenosDeCien(n);
    if (n == 100) return "cien";
    long cen = n / 100, resto = n % 100;
    return CENTENAS[cen] + (resto > 0 ? " " + MenosDeCien(resto) : "");
}

string Spellout(long n)
{
    if (n == 0) return "cero";
    if (n < 0) return "menos " + Spellout(-n);
    if (n == 1) return "uno";

    // Billones (10^12)
    if (n >= 1_000_000_000_000L)
    {
        long bill = n / 1_000_000_000_000L, resto = n % 1_000_000_000_000L;
        string prefix = bill == 1 ? "un billón" : Spellout(bill) + " billones";
        return resto == 0 ? prefix : $"{prefix} {Spellout(resto)}";
    }
    // Millones
    if (n >= 1_000_000L)
    {
        long mill = n / 1_000_000L, resto = n % 1_000_000L;
        string prefix = mill == 1 ? "un millón" : Spellout(mill) + " millones";
        return resto == 0 ? prefix : $"{prefix} {Spellout(resto)}";
    }
    // Miles
    if (n >= 1_000L)
    {
        long miles = n / 1_000L, resto = n % 1_000L;
        string prefix = miles == 1 ? "mil" : Spellout(miles) + " mil";
        return resto == 0 ? prefix : $"{prefix} {MenosDeMil(resto)}";
    }

    return MenosDeMil(n);
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
        var body = Spellout(numero);
        ctx.Response.StatusCode = 200;
        ctx.Response.ContentType = "text/plain; charset=utf-8";
        await ctx.Response.WriteAsync(body);
    }
    catch (Exception ex)
    {
        ctx.Response.StatusCode = 500;
        ctx.Response.ContentType = "text/plain; charset=utf-8";
        await ctx.Response.WriteAsync($"Error: {ex.Message}");
    }
});

Console.WriteLine($"[conintl] Servidor corriendo en http://localhost:{PORT}");
Console.WriteLine($"Prueba: http://localhost:{PORT}/?n=10");

app.Run();