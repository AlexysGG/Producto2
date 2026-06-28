use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::str;

const PORT: u16 = 8000;

// ---------- Implementación manual de número a letras en español ----------
const UNIDADES: [&str; 20] = [
    "", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
    "diez", "once", "doce", "trece", "catorce", "quince", "dieciséis",
    "diecisiete", "dieciocho", "diecinueve",
];

const DECENAS: [&str; 10] = [
    "", "", "veinte", "treinta", "cuarenta", "cincuenta",
    "sesenta", "setenta", "ochenta", "noventa",
];

const CENTENAS: [&str; 10] = [
    "", "ciento", "doscientos", "trescientos", "cuatrocientos", "quinientos",
    "seiscientos", "setecientos", "ochocientos", "novecientos",
];

fn menos_de_veinte(n: usize) -> String {
    UNIDADES[n].to_string()
}

fn menos_de_cien(n: usize) -> String {
    if n < 20 {
        return menos_de_veinte(n);
    }
    let dec = n / 10;
    let uni = n % 10;
    
    if n >= 20 && n < 30 {
        return if uni == 0 { "veinte".to_string() } else { format!("veinti{}", UNIDADES[uni]) };
    }
    
    if uni == 0 {
        DECENAS[dec].to_string()
    } else {
        format!("{} y {}", DECENAS[dec], UNIDADES[uni])
    }
}

fn menos_de_mil(n: usize) -> String {
    if n < 100 {
        return menos_de_cien(n);
    }
    let cen = n / 100;
    let resto = n % 100;
    
    if n == 100 {
        return "cien".to_string();
    }
    
    let sufijo = if resto > 0 { format!(" {}", menos_de_cien(resto)) } else { "".to_string() };
    format!("{}{}", CENTENAS[cen], sufijo)
}

fn spellout_manual(n: i64) -> String {
    let n = n.abs() as usize; // Trabajamos con enteros positivos en base 0

    if n == 0 { return "cero".to_string(); }
    if n == 1 { return "uno".to_string(); }

    // Millones
    if n >= 1_000_000 {
        let millones = n / 1_000_000;
        let resto = n % 1_000_000;
        
        let prefijo = if millones == 1 {
            "un millón".to_string()
        } else {
            format!("{} millones", spellout_manual(millones as i64))
        };
        
        return if resto == 0 { prefijo } else { format!("{} {}", prefijo, spellout_manual(resto as i64)) };
    }

    // Miles
    if n >= 1_000 {
        let miles = n / 1_000;
        let resto = n % 1_000;
        
        let prefijo = if miles == 1 {
            "mil".to_string()
        } else {
            format!("{} mil", spellout_manual(miles as i64))
        };
        
        return if resto == 0 { prefijo } else { format!("{} {}", prefijo, menos_de_mil(resto)) };
    }

    menos_de_mil(n)
}

// ---------- Servidor HTTP Nativo con Sockets ----------
fn handle_client(mut stream: TcpStream) {
    let mut buffer = [0; 1024];
    if stream.read(&mut buffer).is_err() { return; }

    let request_str = match str::from_utf8(&buffer) {
        Ok(v) => v,
        Err(_) => return,
    };

    let first_line = request_str.lines().next().unwrap_or("");
    let parts: Vec<&str> = first_line.split_whitespace().collect();
    if parts.len() < 2 { return; }
    
    let path = parts[1];

    if path == "/favicon.ico" {
        let _ = stream.write_all(b"HTTP/1.1 204 No Content\r\n\r\n");
        return;
    }

    let mut numero_opt: Option<i64> = None;
    if let Some(idx) = path.find("?n=") {
        let query = &path[idx + 3..];
        let num_str = query.split('&').next().unwrap_or("");
        if let Ok(num) = num_str.parse::<i64>() {
            numero_opt = Some(num);
        }
    }

    let (status_line, body) = match numero_opt {
        None => (
            "HTTP/1.1 400 Bad Request", 
            "Uso: /?n=<número>   Ejemplo: /?n=10".to_string()
        ),
        Some(num) => {
            let resultado = spellout_manual(num);
            ("HTTP/1.1 200 OK", resultado)
        }
    };

    let response = format!(
        "{}\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        status_line,
        body.len(),
        body
    );

    let _ = stream.write_all(response.as_bytes());
}

fn main() {
    let listener = TcpListener::bind(format!("127.0.0.1:{}", PORT)).unwrap();
    println!("[conintl] Servidor corriendo en http://localhost:{}", PORT);
    println!("Prueba: http://localhost:{}/?n=10", PORT);

    for stream in listener.incoming() {
        if let Ok(stream) = stream {
            std::thread::spawn(|| {
                handle_client(stream);
            });
        }
    }
}