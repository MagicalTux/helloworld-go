package main

import (
	"fmt"
	"log"
	"net/http"
	"runtime"
	"time"

	"github.com/magicaltux/goupd"
)

var startTime time.Time

type HttpHandler struct{}

type HttpRequest struct {
	W http.ResponseWriter
	R *http.Request
}

func (req *HttpRequest) Printf(format string, a ...interface{}) (int, error) {
	return fmt.Fprintf(req.W, format, a...)
}

func dumpInfo(req *HttpRequest) {
	req.Printf("Informations on platform:\n\n")
	req.Printf("Running version:  %s (build %s %s)\n", goupd.GIT_TAG, goupd.DATE_TAG, goupd.MODE)
	req.Printf("Go version:       %s\n", runtime.Version())
	req.Printf("Uptime:           %s\n", time.Since(startTime))
	req.Printf("Connected client: %s\n", req.R.RemoteAddr)
	if req.R.TLS != nil {
		req.Printf("SSL protocol:     %s\n", req.R.TLS.NegotiatedProtocol)
	}
	req.Printf("\n")

	req.Printf("runtime.NumCPU()       = %d\n", runtime.NumCPU())
	req.Printf("runtime.NumCgoCall()   = %d\n", runtime.NumCgoCall())
	req.Printf("runtime.NumGoroutine() = %d\n\n", runtime.NumGoroutine())

	// memstats
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	req.Printf("MemStats:\n\n")
	req.Printf("General statistics:\n")
	req.Printf("Alloc      = %s\n", formatSize(m.Alloc))
	req.Printf("TotalAlloc = %s\n", formatSize(m.TotalAlloc))
	req.Printf("Sys        = %s\n", formatSize(m.Sys))
	req.Printf("Lookups    = %d\n", m.Lookups)
	req.Printf("Mallocs    = %d\n", m.Mallocs)
	req.Printf("Frees      = %d\n\n", m.Frees)

	req.Printf("Main allocation heap statistics:\n")
	req.Printf("HeapAlloc    = %s\n", formatSize(m.HeapAlloc))
	req.Printf("HeapSys      = %s\n", formatSize(m.HeapSys))
	req.Printf("HeapIdle     = %s\n", formatSize(m.HeapIdle))
	req.Printf("HeapInuse    = %s\n", formatSize(m.HeapInuse))
	req.Printf("HeapReleased = %s\n", formatSize(m.HeapReleased))
	req.Printf("HeapObjects  = %d\n\n", m.HeapObjects)

	req.Printf("Low-level fixed-size structure allocator statistics:\n")
	req.Printf("StackInuse  = %s\n", formatSize(m.StackInuse))
	req.Printf("StackSys    = %s\n", formatSize(m.StackSys))
	req.Printf("MSpanInuse  = %s\n", formatSize(m.MSpanInuse))
	req.Printf("MSpanSys    = %s\n", formatSize(m.MSpanSys))
	req.Printf("MCacheInuse = %s\n", formatSize(m.MCacheInuse))
	req.Printf("MCacheSys   = %s\n", formatSize(m.MCacheSys))
	req.Printf("BuckHashSys = %s\n", formatSize(m.BuckHashSys))
	req.Printf("GCSys       = %s\n", formatSize(m.GCSys))
	req.Printf("OtherSys    = %s\n\n", formatSize(m.OtherSys))

	req.Printf("Garbage collector statistics:\n")
	req.Printf("NextGC        = %s\n", formatSize(m.NextGC))
	req.Printf("LastGC        = %s\n", time.Unix(0, int64(m.LastGC)))
	req.Printf("PauseTotalNs  = %s\n", time.Duration(m.PauseTotalNs))
	req.Printf("PauseNs[%03d]  = %s\n", (m.NumGC+255)%256, time.Duration(m.PauseNs[(m.NumGC+255)%256]))
	req.Printf("PauseEnd[%03d] = %s\n", (m.NumGC+255)%256, time.Unix(0, int64(m.PauseEnd[(m.NumGC+255)%256])))
	req.Printf("NumGC         = %d\n", m.NumGC)
	req.Printf("GCCPUFraction = %f\n", m.GCCPUFraction)
	req.Printf("EnableGC      = %t\n", m.EnableGC)
	req.Printf("DebugGC       = %t\n", m.DebugGC)
}

func (HttpHandler) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	if req.URL.Path == "/_info" {
		dumpInfo(&HttpRequest{w, req})
		return
	}
	w.Header().Set("Content-Type", "text/plain")
	w.Write([]byte("Hello world v2\n"))
}

func main() {
	startTime = time.Now()
	goupd.AutoUpdate(false)

	s := &http.Server{
		Addr:    ":8080",
		Handler: HttpHandler{},
	}

	log.Fatal(s.ListenAndServe())
}
