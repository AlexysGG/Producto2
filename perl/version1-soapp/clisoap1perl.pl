#!/usr/bin/perl
# clisoap1.pl
# Ejecutar: perl clisoap1.pl
# URL:      http://localhost:8000/?n=10  ->  ten
#
# Consume el servicio web SOAP público:
#   https://www.dataaccess.com/webservicesserver/NumberConversion.wso?WSDL
# Devuelve el número en palabras en INGLÉS
#
# Módulos requeridos (instalar con apt):
#   apt install libwww-perl libxml-simple-perl

use strict;
use warnings;
use IO::Socket::INET;
use LWP::UserAgent;
use XML::Simple;

my $SOAP_URL = 'https://www.dataaccess.com/webservicesserver/NumberConversion.wso';
my $PORT     = 8000;

# ── SOAP ──────────────────────────────────────────────────────────────────────

sub build_envelope {
    my ($numero) = @_;
    return <<XML;
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <NumberToWords xmlns="http://www.dataaccess.com/webservicesserver/">
      <ubiNum>$numero</ubiNum>
    </NumberToWords>
  </soap:Body>
</soap:Envelope>
XML
}

sub number_to_words {
    my ($numero) = @_;

    my $envelope = build_envelope($numero);
    my $ua       = LWP::UserAgent->new(timeout => 10);

    my $response = $ua->post(
        $SOAP_URL,
        Content_Type => 'text/xml; charset=utf-8',
        SOAPAction   => 'http://www.dataaccess.com/webservicesserver/NumberToWords',
        Content      => $envelope,
    );

    die "Error HTTP: " . $response->status_line unless $response->is_success;

    # Parsear XML de respuesta
    my $xml  = XML::Simple->new(ForceArray => 0, KeyAttr => []);
    my $data = $xml->XMLin($response->content);

    # Navegar hasta NumberToWordsResult ignorando prefijos de namespace
    # La estructura es: Envelope -> Body -> NumberToWordsResponse -> NumberToWordsResult
    my $body = $data->{'soap:Body'} // $data->{'Body'};
    die "No se encontró soap:Body en la respuesta" unless $body;

    # Buscar recursivamente NumberToWordsResult
    my $result = find_value($body, 'NumberToWordsResult');
    die "No se encontró NumberToWordsResult en la respuesta" unless defined $result;

    return $result;
}

# Busca recursivamente una clave ignorando prefijo de namespace
sub find_value {
    my ($node, $target) = @_;
    return undef unless ref($node) eq 'HASH';

    for my $key (keys %$node) {
        # Ignorar prefijo: "m:NumberToWordsResult" -> "NumberToWordsResult"
        my $local = $key;
        $local =~ s/^[^:]+://;

        if ($local eq $target) {
            return $node->{$key};
        }
        my $found = find_value($node->{$key}, $target);
        return $found if defined $found;
    }
    return undef;
}

# ── Servidor HTTP ──────────────────────────────────────────────────────────────

sub get_param {
    my ($query, $name) = @_;
    return undef unless defined $query;
    for my $pair (split /&/, $query) {
        my ($k, $v) = split /=/, $pair, 2;
        return $v if defined $k && $k eq $name;
    }
    return undef;
}

sub send_response {
    my ($client, $status, $text, $body) = @_;
    print $client "HTTP/1.1 $status $text\r\n";
    print $client "Content-Type: text/plain; charset=utf-8\r\n";
    print $client "Content-Length: " . length($body) . "\r\n";
    print $client "Connection: close\r\n";
    print $client "\r\n";
    print $client $body;
}

my $server = IO::Socket::INET->new(
    LocalPort => $PORT,
    Type      => SOCK_STREAM,
    Reuse     => 1,
    Listen    => 10,
) or die "No se pudo iniciar el servidor en el puerto $PORT: $!";

print "[clisoap1] Servidor corriendo en http://localhost:$PORT\n";
print "Prueba: http://localhost:$PORT/?n=10\n";

while (my $client = $server->accept()) {
    $client->autoflush(1);

    # Leer la petición HTTP
    my $request_line = <$client>;
    chomp $request_line;

    # Descartar el resto de los headers
    while (my $line = <$client>) {
        last if $line =~ /^\r?\n$/;
    }

    # Ignorar favicon
    if ($request_line =~ m{GET /favicon\.ico}) {
        print $client "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n";
        close $client;
        next;
    }

    # Extraer query string: GET /?n=10 HTTP/1.1
    my ($query) = $request_line =~ m{GET /\?(.+) HTTP}i;
    my $n = get_param($query, 'n');

    my ($status_code, $status_text, $body);

    if (!defined $n || $n !~ /^-?\d+$/) {
        ($status_code, $status_text, $body) = (400, 'Bad Request', 'Uso: /?n=<numero>   Ejemplo: /?n=10');
    } else {
        eval {
            $body = number_to_words($n);
            ($status_code, $status_text) = (200, 'OK');
        };
        if ($@) {
            ($status_code, $status_text, $body) = (500, 'Internal Server Error', "Error al llamar al servicio SOAP: $@");
        }
    }

    send_response($client, $status_code, $status_text, $body);
    close $client;
}