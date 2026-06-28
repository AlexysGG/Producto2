require 'socket'
require 'uri'

PORT = 8000

# ---------- Implementación manual de número a letras en español ----------
UNIDADES = [
  "", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
  "diez", "once", "doce", "trece", "catorce", "quince", "dieciséis",
  "diecisiete", "dieciocho", "diecinueve"
]

DECENAS = [
  "", "", "veinte", "treinta", "cuarenta", "cincuenta",
  "sesenta", "setenta", "ochenta", "noventa"
]

CENTENAS = [
  "", "ciento", "doscientos", "trescientos", "cuatrocientos", "quinientos",
  "seiscientos", "setecientos", "ochocientos", "novecientos"
]

def menos_de_veinte(n)
  UNIDADES[n]
end

def menos_de_cien(n)
  return menos_de_veinte(n) if n < 20
  
  dec = n / 10
  uni = n % 10
  
  if n >= 20 && n < 30
    return uni == 0 ? "veinte" : "veinti" + UNIDADES[uni]
  end
  
  uni == 0 ? DECENAS[dec] : "#{DECENAS[dec]} y #{UNIDADES[uni]}"
end

def menos_de_mil(n)
  return menos_de_cien(n) if n < 100
  
  cen = n / 100
  resto = n % 100
  
  return "cien" if n == 100
  
  sufijo = resto > 0 ? " " + menos_de_cien(resto) : ""
  CENTENAS[cen] + sufijo
end

def spellout_manual(n)
  n = n.abs.to_i # trabajamos con enteros positivos

  return "cero" if n == 0
  return "uno" if n == 1

  # Millones
  if n >= 1_000_000
    millones = n / 1_000_000
    resto = n % 1_000_000
    
    prefijo = millones == 1 ? "un millón" : spellout_manual(millones) + " millones"
    return resto == 0 ? prefijo : prefijo + " " + spellout_manual(resto)
  end

  # Miles
  if n >= 1_000
    miles = n / 1_000
    resto = n % 1_000
    
    prefijo = miles == 1 ? "mil" : spellout_manual(miles) + " mil"
    return resto == 0 ? prefijo : prefijo + " " + menos_de_mil(resto)
  end

  menos_de_mil(n)
end

# ---------- Servidor HTTP Nativo con Sockets ----------
server = TCPServer.new(PORT)
puts "[conintl] Servidor corriendo en http://localhost:#{PORT}"
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

    # Validación: verificar que no esté vacío y que sea numérico
    if n.nil? || n.empty? || n.to_i.to_s != n
      body = "Uso: /?n=<número>   Ejemplo: /?n=10"
      client.print "HTTP/1.1 400 Bad Request\r\n" \
                   "Content-Type: text/plain; charset=utf-8\r\n" \
                   "Content-Length: #{body.bytesize}\r\n" \
                   "Connection: close\r\n\r\n"
      client.print body
    else
      resultado = spellout_manual(n.to_i)
      
      client.print "HTTP/1.1 200 OK\r\n" \
                   "Content-Type: text/plain; charset=utf-8\r\n" \
                   "Content-Length: #{resultado.bytesize}\r\n" \
                   "Connection: close\r\n\r\n"
      client.print resultado
    end
    client.close
  end
end