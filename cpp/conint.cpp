#include <iostream>
#include <string>
#include <sstream>
#include <vector>
#include <cmath>
#include <winsock2.h>

#pragma comment(lib, "ws2_32.lib")

const int PORT = 8000;

const std::vector<std::string> UNIDADES = {
    "", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
    "diez", "once", "doce", "trece", "catorce", "quince", "dieciséis",
    "diecisiete", "dieciocho", "diecinueve"
};

const std::vector<std::string> DECENAS = {
    "", "", "veinte", "treinta", "cuarenta", "cincuenta",
    "sesenta", "setenta", "ochenta", "noventa"
};

const std::vector<std::string> CENTENAS = {
    "", "ciento", "doscientos", "trescientos", "cuatrocientos", "quinientos",
    "seiscientos", "setecientos", "ochocientos", "novecientos"
};

std::string menosDeCien(size_t n) {
    if (n < 20) return UNIDADES[n];
    size_t dec = n / 10;
    size_t uni = n % 10;
    if (n >= 20 && n < 30) {
        return (uni == 0) ? "veinte" : "veinti" + UNIDADES[uni];
    }
    return (uni == 0) ? DECENAS[dec] : DECENAS[dec] + " y " + UNIDADES[uni];
}

std::string menosDeMil(size_t n) {
    if (n < 100) return menosDeCien(n);
    size_t cen = n / 100;
    size_t resto = n % 100;
    if (n == 100) return "cien";
    std::string sufijo = (resto > 0) ? " " + menosDeCien(resto) : "";
    return CENTENAS[cen] + sufijo;
}

std::string spelloutManual(long long n) {
    size_t val = std::abs(n);
    if (val == 0) return "cero";
    if (val == 1) return "uno";

    if (val >= 1000000) {
        size_t millones = val / 1000000;
        size_t resto = val % 1000000;
        std::string prefijo = (millones == 1) ? "un millón" : spelloutManual(millones) + " millones";
        return (resto == 0) ? prefijo : prefijo + " " + spelloutManual(resto);
    }

    if (val >= 1000) {
        size_t miles = val / 1000;
        size_t resto = val % 1000;
        std::string prefijo = (miles == 1) ? "mil" : spelloutManual(miles) + " mil";
        return (resto == 0) ? prefijo : prefijo + " " + menosDeMil(resto);
    }

    return menosDeMil(val);
}

void handleClient(SOCKET clientSocket) {
    char buffer[1024] = {0};
    recv(clientSocket, buffer, sizeof(buffer) - 1, 0);
    std::string request(buffer);

    std::size_t pos = request.find("GET /?n=");
    if (pos == std::string::npos) {
        std::string body = "Uso: /?n=<numero>";
        std::string resp = "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: " + std::to_string(body.length()) + "\r\nConnection: close\r\n\r\n" + body;
        send(clientSocket, resp.c_str(), resp.length(), 0);
        closesocket(clientSocket);
        return;
    }

    std::string query = request.substr(pos + 8);
    std::size_t endPos = query.find_first_of(" &\r\n");
    std::string numStr = query.substr(0, endPos);
    
    long long numero = std::stoll(numStr);
    std::string resultado = spelloutManual(numero);

    std::string response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: " + std::to_string(resultado.length()) + "\r\nConnection: close\r\n\r\n" + resultado;
    send(clientSocket, response.c_str(), response.length(), 0);
    closesocket(clientSocket);
}

int main() {
    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);
    SOCKET serverSocket = socket(AF_INET, SOCK_STREAM, 0);

    sockaddr_in serverAddr{};
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_addr.s_addr = INADDR_ANY;
    serverAddr.sin_port = htons(PORT);

    bind(serverSocket, (struct sockaddr*)&serverAddr, sizeof(serverAddr));
    listen(serverSocket, 3);

    std::cout << "[conintl] Servidor C++ corriendo en http://localhost:" << PORT << "\n";

    while (true) {
        SOCKET clientSocket = accept(serverSocket, nullptr, nullptr);
        if (clientSocket != INVALID_SOCKET) {
            handleClient(clientSocket);
        }
    }
    closesocket(serverSocket);
    WSACleanup();
    return 0;
}