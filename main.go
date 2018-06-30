package main

import (
	"log"
	"net/http"
)

type HttpHandler struct{}

func (HttpHandler) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	w.Header().Set("Content-Type", "text/plain")
	w.Write([]byte("Hello world"))
}

func main() {
	s := &http.Server{
		Addr:    ":8080",
		Handler: HttpHandler{},
	}

	log.Fatal(s.ListenAndServe())
}
