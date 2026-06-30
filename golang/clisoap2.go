package main

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
)

const (
	WSDL_URL = "https://www.dataaccess.com/webservicesserver/NumberConversion.wso"
	PORT     = ":8000"
)

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

	startTag := "NumberToWordsResult>"
	startIdx := strings.Index(bodyStr, startTag)
	if startIdx == -1 {
		return "", fmt.Errorf("no se encontró NumberToWordsResult")
	}

	subStr := bodyStr[startIdx+len(startTag):]
	endIdx := strings.Index(subStr, "</")
	if endIdx == -1 {
		return "", fmt.Errorf("error al parsear XML")
	}

	return strings.TrimSpace(subStr[:endIdx]), nil
}

// Traduce el texto usando la API libre de Google Translate sin dependencias externas JSON
func translateToSpanish(texto string) (string, error) {
	textoCodificado := url.QueryEscape(texto)
	urlTranslate := fmt.Sprintf("https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=es&dt=t&q=%s", textoCodificado)

	resp, err := http.Get(urlTranslate)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	bodyStr := string(bodyBytes)

	// Google responde en un formato JSON anidado array de arrays: [[["diez","ten",null,...]]]
	// Extraemos el texto aislando los caracteres dentro de las primeras comillas
	startIdx := strings.Index(bodyStr, "\"")
	if startIdx == -1 {
		return "", fmt.Errorf("error al procesar respuesta de traducción")
	}

	resto := bodyStr[startIdx+1:]
	endIdx := strings.Index(resto, "\"")
	if endIdx == -1 {
		return "", fmt.Errorf("error al cerrar comillas de traducción")
	}

	return strings.ToLower(resto[:endIdx]), nil
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

		// 1. Obtener número en inglés
		enIngles, err := numberToWords(numero)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(fmt.Sprintf("Error SOAP: %s", err.Error())))
			return
		}

		// 2. Traducir al español
		enEspanol, err := translateToSpanish(enIngles)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(fmt.Sprintf("Error Traducción: %s", err.Error())))
			return
		}

		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(enEspanol))
	})

	fmt.Printf("[clisoap2] Servidor Go corriendo en http://localhost%s\n", PORT)
	fmt.Printf("Prueba: http://localhost%s/?n=10\n", PORT)

	if err := http.ListenAndServe(PORT, nil); err != nil {
		panic(err)
	}
}