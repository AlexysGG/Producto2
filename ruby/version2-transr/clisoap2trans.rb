require 'socket'
require 'net/http'
require 'uri'
require 'rexml/document'
require 'json' # Requerido para procesar la respuesta de Google Translate

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

# Realiza la petición SOAP y obtiene el número en inglés
def number_to_words(numero)
  envelope = build_soap_envelope(numero)
  uri = URI.parse(WSDL_URL)
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  
  request = Net::HTTP::Post.new(uri.path)
  request['Content-Type'] = 'text/xml; charset=utf-8'
  request['SOAPAction'] = 'http://www.dataaccess.com/webservicesserver/NumberToWords'
  request.body = envelope
  
  response = http.request(request)
  
  unless response.code.to_i == 200
    raise "Error en la petición SOAP: Código #{response.code}"
  end
  
  doc = REXML::Document.new(response.body)
  resultado_nodo = REXML::XPath.first(doc, "//*[local-name()='NumberToWordsResult']")
  
  raise "No se encontró el resultado en el XML" if resultado_nodo.nil?
  
  resultado_nodo.text.strip
end

# Traduce el texto de inglés a español usando la API libre de Google Translate
def translate_to_spanish(texto)
  # Codificar el texto para que sea seguro en una URL
  texto_codificado = URI.encode_www_form_component(texto)
  url_translate = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=es&dt=t&q=#{texto_codificado}"
  
  uri = URI.parse(url_translate)
  response = Net::HTTP.get_response(uri)
  
  unless response.code.to_i == 200
    raise "Error al traducir el texto"
  end
  
  # La respuesta de Google viene en un array anidado complejo: [[[ "resultado", "original", ... ]]]
  resultado_json = JSON.parse(response.body)
  resultado_json[0][0][0].strip.downcase
end

# ---------- Servidor HTTP Nativo con Sockets ----------
server = TCPServer.new(PORT)
puts "[clisoap2] Servidor corriendo en http://localhost:#{PORT}"
puts "Prueba: http://localhost:#{PORT}/?n=10"

loop do
  Thread.start(server.accept) do |client|
    request_line = client.gets
    next if request_line.nil?

    method, path, _ = request_line.split(" ")
    
    if path == '/favicon.ico'
      client.print "HTTP/1.1 204 No Content\r\n\r\n"
      client.close
      next
    end

    uri = URI.parse(path)
    params = uri.query ? URI.decode_www_form(uri.query).to_h : {}
    n = params['n']

    if n.nil? || n.empty? || n.to_i.to_s != n
      body = "Uso: /?n=<numero>   Ejemplo: /?n=10"
      client.print "HTTP/1.1 400 Bad Request\r\n" \
                   "Content-Type: text/plain; charset=utf-8\r\n" \
                   "Content-Length: #{body.bytesize}\r\n" \
                   "Connection: close\r\n\r\n"
      client.print body
    else
      begin
        # 1. Obtener texto en inglés ("ten")
        en_ingles = number_to_words(n.to_i)
        # 2. Traducir a español ("diez")
        en_espanol = translate_to_spanish(en_ingles)
        
        client.print "HTTP/1.1 200 OK\r\n" \
                     "Content-Type: text/plain; charset=utf-8\r\n" \
                     "Content-Length: #{en_espanol.bytesize}\r\n" \
                     "Connection: close\r\n\r\n"
        client.print en_espanol
      rescue => err
        body = "Error: #{err.message}"
        client.print "HTTP/1.1 500 Internal Server Error\r\n" \
                     "Content-Type: text/plain; charset=utf-8\r\n" \
                     "Content-Length: #{body.bytesize}\r\n" \
                     "Connection: close\r\n\r\n"
        client.print body
      end
    end
    client.close
  end
end