package main

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
)

const (
	WSDL_URL = "https://www.dataaccess.com/webservicesserver/NumberConversion.wso"
	PORT     = ":8000"
)

// Construye el sobre XML para la petición SOAP
func buildSoapEnvelope(numero int64) string {
	return fmt.Sprintf(`<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <NumberToWords xmlns="http://www.dataaccess.com/webservicesserver/">
      <ubiNum>%d</ubiNum>
    </NumberToWords>
  </soap:Body>
</soap:Envelope>`, numero)
}

// Envía la petición SOAP y extrae el resultado del XML textualmente
func numberToWords(numero int64) (string, error) {
	envelope := buildSoapEnvelope(numero)

	req, err := http.NewRequest("POST", WSDL_URL, bytes.NewBufferString(envelope))
	if err != nil {
		return "", err
	}

	req.Header.Set("Content-Type", "text/xml; charset=utf-8")
	req.Header.Set("SOAPAction", "http://www.dataaccess.com/webservicesserver/NumberToWords")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	bodyStr := string(bodyBytes)

	// Extraer el valor de <NumberToWordsResult> de forma manual y eficiente
	startTag := "NumberToWordsResult>"
	startIdx := strings.Index(bodyStr, startTag)
	if startIdx == -1 {
		return "", fmt.Errorf("no se encontró NumberToWordsResult en el XML")
	}

	subStr := bodyStr[startIdx+len(startTag):]
	endIdx := strings.Index(subStr, "</")
	if endIdx == -1 {
		return "", fmt.Errorf("error al parsear el final de la etiqueta XML")
	}

	return strings.TrimSpace(subStr[:endIdx]), nil
}

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/favicon.ico" {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		nParam := r.URL.Query().Get("n")
		numero, err := strconv.ParseInt(nParam, 10, 64)
		if nParam == "" || err != nil {
			w.Header().Set("Content-Type", "text/plain; charset=utf-8")
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte("Uso: /?n=<numero>   Ejemplo: /?n=10"))
			return
		}

		palabras, err := numberToWords(numero)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(fmt.Sprintf("Error: %s", err.Error())))
			return
		}

		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(palabras))
	})

	fmt.Printf("[clisoap1] Servidor Go corriendo en http://localhost%s\n", PORT)
	fmt.Printf("Prueba: http://localhost%s/?n=10\n", PORT)

	if err := http.ListenAndServe(PORT, nil); err != nil {
		panic(err)
	}
}