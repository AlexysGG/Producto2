#include <iostream>
#include <string>
#include <winsock2.h>
#include <wininet.h>

#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "wininet.lib")

const int PORT = 8000;

std::string performSoapRequest(long long numero) {
    std::string envelope = 
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n"
        "<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\r\n"
        "  <soap:Body>\r\n"
        "    <NumberToWords xmlns=\"http://www.dataaccess.com/webservicesserver/\">\r\n"
        "      <ubiNum>" + std::to_string(numero) + "</ubiNum>\r\n"
        "    </NumberToWords>\r\n"
        "  </soap:Body>\r\n"
        "</soap:Envelope>";

    HINTERNET hInternet = InternetOpenA("SoapClient", INTERNET_OPEN_TYPE_DIRECT, NULL, NULL, 0);
    HINTERNET hConnect = InternetConnectA(hInternet, "www.dataaccess.com", INTERNET_DEFAULT_HTTPS_PORT, NULL, NULL, INTERNET_SERVICE_HTTP, 0, 0);
    HINTERNET hRequest = HttpOpenRequestA(hConnect, "POST", "/webservicesserver/NumberConversion.wso", NULL, NULL, NULL, INTERNET_FLAG_SECURE, 0);

    std::string headers = "Content-Type: text/xml; charset=utf-8\r\nSOAPAction: http://www.dataaccess.com/webservicesserver/NumberToWords";
    HttpSendRequestA(hRequest, headers.c_str(), headers.length(), (LPVOID)envelope.c_str(), envelope.length());

    std::string responseText;
    char buffer[1024];
    DWORD bytesRead;
    while (InternetReadFile(hRequest, buffer, sizeof(buffer) - 1, &bytesRead) && bytesRead > 0) {
        buffer[bytesRead] = '\0';
        responseText += buffer;
    }

    InternetCloseHandle(hRequest);
    InternetCloseHandle(hConnect);
    InternetCloseHandle(hInternet);

    std::size_t startIdx = responseText.find("NumberToWordsResult>");
    if (startIdx != std::string::npos) {
        std::string sub = responseText.substr(startIdx + 20);
        std::size_t endIdx = sub.find("</");
        return sub.substr(0, endIdx);
    }
    return "Error XML";
}

void handleClient(SOCKET clientSocket) {
    char buffer[1024] = {0};
    recv(clientSocket, buffer, sizeof(buffer) - 1, 0);
    std::string request(buffer);

    std::size_t pos = request.find("GET /?n=");
    if (pos == std::string::npos) {
        std::string body = "Uso: /?n=<numero>";
        std::string resp = "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\nContent-Length: " + std::to_string(body.length()) + "\r\n\r\n" + body;
        send(clientSocket, resp.c_str(), resp.length(), 0);
        closesocket(clientSocket);
        return;
    }

    std::string numStr = request.substr(pos + 8, request.find_first_of(" &\r\n", pos + 8) - (pos + 8));
    std::string resultado = performSoapRequest(std::stoll(numStr));

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
    std::cout << "[clisoap1] Servidor C++ corriendo en http://localhost:" << PORT << "\n";

    while (true) {
        SOCKET clientSocket = accept(serverSocket, nullptr, nullptr);
        if (clientSocket != INVALID_SOCKET) handleClient(clientSocket);
    }
    closesocket(serverSocket);
    WSACleanup();
    return 0;
}