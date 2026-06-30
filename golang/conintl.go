package main

import (
	"fmt"
	"math"
	"net/http"
	"strconv"
)

const PORT = ":8000"

// ---------- Implementación manual de número a letras en español ----------
var UNIDADES = []string{
	"", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
	"diez", "once", "doce", "trece", "catorce", "quince", "dieciséis",
	"diecisiete", "dieciocho", "diecinueve",
}

var DECENAS = []string{
	"", "", "veinte", "treinta", "cuarenta", "cincuenta",
	"sesenta", "setenta", "ochenta", "noventa",
}

var CENTENAS = []string{
	"", "ciento", "doscientos", "trescientos", "cuatrocientos", "quinientos",
	"seiscientos", "setecientos", "ochocientos", "novecientos",
}

func menosDeVeinte(n int) string {
	return UNIDADES[n]
}

func menosDeCien(n int) string {
	if n < 20 {
		return menosDeVeinte(n)
	}
	dec := n / 10
	uni := n % 10

	if n >= 20 && n < 30 {
		if uni == 0 {
			return "veinte"
		}
		return "veinti" + UNIDADES[uni]
	}

	if uni == 0 {
		return DECENAS[dec]
	}
	return fmt.Sprintf("%s y %s", DECENAS[dec], UNIDADES[uni])
}

func menosDeMil(n int) string {
	if n < 100 {
		return menosDeCien(n)
	}
	cen := n / 100
	resto := n % 100

	if n == 100 {
		return "cien"
	}

	sufijo := ""
	if resto > 0 {
		sufijo = " " + menosDeCien(resto)
	}
	return CENTENAS[cen] + sufijo
}

func spelloutManual(n int64) string {
	// Trabajamos con el valor absoluto entero positivo
	val := int(math.Abs(float64(n)))

	if val == 0 {
		return "cero"
	}
	if val == 1 {
		return "uno"
	}

	// Millones
	if val >= 1000000 {
		millones := val / 1000000
		resto := val % 1000000

		prefijo := ""
		if millones == 1 {
			prefijo = "un millón"
		} else {
			prefijo = spelloutManual(int64(millones)) + " millones"
		}

		if resto == 0 {
			return prefijo
		}
		return prefijo + " " + spelloutManual(int64(resto))
	}

	// Miles
	if val >= 1000 {
		miles := val / 1000
		resto := val % 1000

		prefijo := ""
		if miles == 1 {
			prefijo = "mil"
		} else {
			prefijo = spelloutManual(int64(miles)) + " mil"
		}

		if resto == 0 {
			return prefijo
		}
		return prefijo + " " + menosDeMil(resto)
	}

	return menosDeMil(val)
}

// ---------- Servidor HTTP ----------
func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// Ignorar favicon
		if r.URL.Path == "/favicon.ico" {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		// Extraer el parámetro 'n' de la Query String
		nParam := r.URL.Query().Get("n")

		// Validación: que no esté vacío y sea un número válido
		numero, err := strconv.ParseInt(nParam, 10, 64)
		if nParam == "" || err != nil {
			w.Header().Set("Content-Type", "text/plain; charset=utf-8")
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte("Uso: /?n=<número>   Ejemplo: /?n=10"))
			return
		}

		// Convertir el número a palabras en español
		resultado := spelloutManual(numero)

		// Enviar respuesta
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(resultado))
	})

	fmt.Printf("[conintl] Servidor Go corriendo en http://localhost%s\n", PORT)
	fmt.Printf("Prueba: http://localhost%s/?n=10\n", PORT)
	
	// Iniciar el servidor nativo
	if err := http.ListenAndServe(PORT, nil); err != nil {
		panic(err)
	}
}