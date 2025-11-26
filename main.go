package main

import (
	"crypto/tls"
	"flag"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"

	"tailscale.com/tsnet"
)

func main() {
	hostname := os.Getenv("TS_HOSTNAME")
	if hostname == "" {
		hostname = "laravel"
	}

	targetHost := os.Getenv("TARGET_HOST")
	if targetHost == "" {
		log.Fatal("TARGET_HOST environment variable is required")
	}

	targetPort := os.Getenv("TARGET_PORT")
	if targetPort == "" {
		targetPort = "8080"
	}

	stateDir := os.Getenv("TS_STATE_DIR")
	if stateDir == "" {
		stateDir = "/var/lib/tailscale"
	}

	flag.Parse()

	targetURL, err := url.Parse("http://" + targetHost + ":" + targetPort)
	if err != nil {
		log.Fatalf("Invalid target URL: %v", err)
	}

	log.Printf("Starting tsnet proxy: %s -> %s", hostname, targetURL)

	// Create tsnet server
	s := &tsnet.Server{
		Hostname: hostname,
		Dir:      stateDir,
	}

	defer s.Close()

	// Get HTTPS listener with automatic TLS certs
	ln, err := s.ListenTLS("tcp", ":443")
	if err != nil {
		log.Fatalf("Failed to listen on :443: %v", err)
	}
	defer ln.Close()

	// Also listen on HTTP (port 80) and redirect to HTTPS
	ln80, err := s.Listen("tcp", ":80")
	if err != nil {
		log.Printf("Warning: Failed to listen on :80: %v", err)
	} else {
		defer ln80.Close()
		go http.Serve(ln80, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			target := "https://" + r.Host + r.URL.Path
			if r.URL.RawQuery != "" {
				target += "?" + r.URL.RawQuery
			}
			http.Redirect(w, r, target, http.StatusMovedPermanently)
		}))
	}

	// Create reverse proxy
	proxy := httputil.NewSingleHostReverseProxy(targetURL)

	// Handle connection errors gracefully
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("Proxy error: %v", err)
		http.Error(w, "Bad Gateway", http.StatusBadGateway)
	}

	// Skip TLS verification for backend (Railway internal)
	proxy.Transport = &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}

	log.Printf("Listening on https://%s.ts.net", hostname)
	log.Fatal(http.Serve(ln, proxy))
}
