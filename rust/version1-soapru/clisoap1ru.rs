use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::str;

const WSDL_URL: &str = "https://www.dataaccess.com/webservicesserver/NumberConversion.wso";
const PORT: u16 = 8000;

fn build_soap_envelope(numero: i64) -> String {
    format!(
        r#"<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <NumberToWords xmlns="http://www.dataaccess.com/webservicesserver/">
      <ubiNum>{}</ubiNum>
    </NumberToWords>
  </soap:Body>
</soap:Envelope>"#,
        numero
    )
}

fn number_to_words(numero: i64) -> Result<String, Box<dyn std::error::Error>> {
    let envelope = build_soap_envelope(numero);
    
    let client = reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_secs(5))
        .build()?;

    let response = client
        .post(WSDL_URL)
        .header("Content-Type", "text/xml; charset=utf-8")
        .header("SOAPAction", "http://www.dataaccess.com/webservicesserver/NumberToWords")
        .body(envelope)
        .send()?;

    let response_text = response.text()?;

    if let Some(start_idx) = response_text.find("NumberToWordsResult>") {
        let sub_str = &response_text[start_idx..];
        if let Some(end_idx) = sub_str.find("</") {
            let valor = &sub_str[20..end_idx];
            return Ok(valor.trim().to_string());
        }
    }

    Err("No se encontró NumberToWordsResult en el XML".into())
}

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
            "Uso: /?n=<numero>   Ejemplo: /?n=10".to_string()
        ),
        Some(num) => match number_to_words(num) {
            Ok(palabras) => ("HTTP/1.1 200 OK", palabras),
            Err(err) => ("HTTP/1.1 500 Internal Server Error", format!("Error: {}", err)),
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
    println!("[clisoap1] Servidor corriendo en http://localhost:{}", PORT);
    println!("Prueba: http://localhost:{}/?n=10", PORT);

    for stream in listener.incoming() {
        if let Ok(stream) = stream {
            std::thread::spawn(|| {
                handle_client(stream);
            });
        }
    }
}