require 'webrick'
require 'net/http'
require 'uri'
require 'rexml/document'

WSDL_URL = "https://www.dataaccess.com/webservicesserver/NumberConversion.wso"
PORT = 8000

# Construye el XML para la petición SOAP
def build_soap_envelope(numero)
  <<~XML
    <?xml version="1.0" encoding="utf-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Body>
        <NumberToWords xmlns="http://www.dataaccess.com/webservicesserver/">
          <ubiNum>#{numero}</ubiNum>
        </NumberToWords>
      </soap:Body>
    </soap:Envelope>
  XML
end

# Realiza la petición SOAP y parsea la respuesta
def number_to_words(numero)
  envelope = build_soap_envelope(numero)
  uri = URI.parse(WSDL_URL)
  
  # Configurar cliente HTTP
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  
  # Configurar Headers y Body
  request = Net::HTTP::Post.new(uri.path)
  request['Content-Type'] = 'text/xml; charset=utf-8'
  request['SOAPAction'] = 'http://www.dataaccess.com/webservicesserver/NumberToWords'
  request.body = envelope
  
  response = http.request(request)
  
  unless response.code.to_i == 200
    raise "Error en la petición SOAP: Código #{response.code}"
  end
  
  # Parsear el XML de respuesta usando REXML
  doc = REXML::Document.new(response.body)
  
  # Buscar el nodo ignorando el prefijo del namespace usando XPath local-name()
  resultado_nodo = REXML::XPath.first(doc, "//*[local-name()='NumberToWordsResult']")
  
  if resultado_nodo.nil?
    raise "No se encontró NumberToWordsResult en la respuesta:\n#{response.body}"
  end
  
  resultado_nodo.text.strip
end

# ---------- Servidor HTTP (WEBrick) ----------
server = WEBrick::HTTPServer.new(Port: PORT)

server.mount_proc '/' do |req, res|
  if req.path == '/favicon.ico'
    res.status = 204
    return
  end

  n = req.query['n']

  # Validación básica de que existe el parámetro y es un número entero
  if n.nil? || n.empty? || n.to_i.to_s != n
    res.status = 400
    res.content_type = 'text/plain; charset=utf-8'
    res.body = "Uso: /?n=<numero>   Ejemplo: /?n=10"
    return
  end

  begin
    res.status = 200
    res.content_type = 'text/plain; charset=utf-8'
    res.body = number_to_words(n.to_i)
  rescue => err
    res.status = 500
    res.content_type = 'text/plain; charset=utf-8'
    res.body = "Error: #{err.message}"
  end
end

# Capturar la interrupción (Ctrl+C) para apagar el servidor limpiamente
trap('INT') { server.shutdown }

puts "[clisoap1] Servidor corriendo en http://localhost:#{PORT}"
puts "Prueba: http://localhost:#{PORT}/?n=10"
server.start