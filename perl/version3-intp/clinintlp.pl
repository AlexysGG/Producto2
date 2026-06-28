#!/usr/bin/perl
# conintl.pl
# Ejecutar: perl conintl.pl
# URL:      http://localhost:8000/?n=10  ->  diez
#
# Convierte un número a letras en ESPAÑOL.
# Implementación propia sin módulos externos.
# Equivalente a: new NumberFormatter("es", NumberFormatter::SPELLOUT) de PHP
#
# Sin módulos externos — solo Perl core

use strict;
use warnings;
use utf8;                    # permite tildes en el código fuente
use open ':std', ':utf8';    # salida en UTF-8
use IO::Socket::INET;

my $PORT = 8000;

# ── Tablas de conversión ───────────────────────────────────────────────────────

my @UNIDADES = (
    '', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve',
    'diez', 'once', 'doce', 'trece', 'catorce', 'quince',
    'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve',
);

my @DECENAS = (
    '', '', 'veinte', 'treinta', 'cuarenta', 'cincuenta',
    'sesenta', 'setenta', 'ochenta', 'noventa',
);

# "ciento" para 101-199; exactamente 100 se maneja aparte como "cien"
my @CENTENAS = (
    '', 'ciento', 'doscientos', 'trescientos', 'cuatrocientos', 'quinientos',
    'seiscientos', 'setecientos', 'ochocientos', 'novecientos',
);

# ── Lógica de conversión ───────────────────────────────────────────────────────

sub menos_de_cien {
    my ($n) = @_;
    return $UNIDADES[$n] if $n < 20;
    my $dec = int($n / 10);
    my $uni = $n % 10;
    if ($n < 30) {    # 20-29: veinti + algo
        return $uni == 0 ? 'veinte' : 'veinti' . $UNIDADES[$uni];
    }
    return $uni == 0 ? $DECENAS[$dec] : "$DECENAS[$dec] y $UNIDADES[$uni]";
}

sub menos_de_mil {
    my ($n) = @_;
    return menos_de_cien($n) if $n < 100;
    return 'cien'            if $n == 100;
    my $cen   = int($n / 100);
    my $resto = $n % 100;
    return $CENTENAS[$cen] . ($resto > 0 ? ' ' . menos_de_cien($resto) : '');
}

sub spellout {
    my ($n) = @_;
    $n = int($n);
    return 'cero'              if $n == 0;
    return 'menos ' . spellout(-$n) if $n < 0;
    return 'uno'               if $n == 1;

    # Billones (10^12)
    if ($n >= 1_000_000_000_000) {
        my $bill  = int($n / 1_000_000_000_000);
        my $resto = $n % 1_000_000_000_000;
        my $prefix = $bill == 1 ? 'un billón' : spellout($bill) . ' billones';
        return $resto == 0 ? $prefix : "$prefix " . spellout($resto);
    }
    # Millones
    if ($n >= 1_000_000) {
        my $mill  = int($n / 1_000_000);
        my $resto = $n % 1_000_000;
        my $prefix = $mill == 1 ? 'un millón' : spellout($mill) . ' millones';
        return $resto == 0 ? $prefix : "$prefix " . spellout($resto);
    }
    # Miles
    if ($n >= 1_000) {
        my $miles = int($n / 1_000);
        my $resto = $n % 1_000;
        my $prefix = $miles == 1 ? 'mil' : spellout($miles) . ' mil';
        return $resto == 0 ? $prefix : "$prefix " . menos_de_mil($resto);
    }

    return menos_de_mil($n);
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
    # Codificar en UTF-8 para el Content-Length correcto
    my $bytes = Encode::encode('UTF-8', $body);
    print $client "HTTP/1.1 $status $text\r\n";
    print $client "Content-Type: text/plain; charset=utf-8\r\n";
    print $client "Content-Length: " . length($bytes) . "\r\n";
    print $client "Connection: close\r\n";
    print $client "\r\n";
    print $client $bytes;
}

use Encode;

my $server = IO::Socket::INET->new(
    LocalPort => $PORT,
    Type      => SOCK_STREAM,
    Reuse     => 1,
    Listen    => 10,
) or die "No se pudo iniciar el servidor en el puerto $PORT: $!";

print "[conintl] Servidor corriendo en http://localhost:$PORT\n";
print "Prueba: http://localhost:$PORT/?n=10\n";

while (my $client = $server->accept()) {
    $client->autoflush(1);

    my $request_line = <$client>;
    chomp $request_line;

    while (my $line = <$client>) {
        last if $line =~ /^\r?\n$/;
    }

    if ($request_line =~ m{GET /favicon\.ico}) {
        print $client "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n";
        close $client;
        next;
    }

    my ($query) = $request_line =~ m{GET /\?(.+) HTTP}i;
    my $n = get_param($query, 'n');

    my ($status_code, $status_text, $body);

    if (!defined $n || $n !~ /^-?\d+$/) {
        ($status_code, $status_text, $body) = (400, 'Bad Request', 'Uso: /?n=<numero>   Ejemplo: /?n=10');
    } else {
        eval {
            $body = spellout(int($n));
            ($status_code, $status_text) = (200, 'OK');
        };
        if ($@) {
            ($status_code, $status_text, $body) = (500, 'Internal Server Error', "Error: $@");
        }
    }

    send_response($client, $status_code, $status_text, $body);
    close $client;
}