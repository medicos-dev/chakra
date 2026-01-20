package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"sync"

	"github.com/gorilla/websocket"
)

var (
	clients   = make(map[string]*websocket.Conn)
	clientsMu sync.Mutex
	upgrader  = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}
)

type SignalMessage struct {
	Type      string      `json:"type"` // offer, answer, candidate, register
	From      string      `json:"from"`
	To        string      `json:"to"`
	SDP       interface{} `json:"sdp,omitempty"`
	Candidate interface{} `json:"candidate,omitempty"`
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "10000"
	}

	http.HandleFunc("/ws", handleWebSocket)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("Chakra Signaling Server is LIVE"))
	})

	log.Printf("Signaling Server starting on 0.0.0.0:%s", port)
	log.Fatal(http.ListenAndServe("0.0.0.0:"+port, nil))
}

func handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()

	var clientID string
	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			break
		}

		var sig SignalMessage
		if err := json.Unmarshal(msg, &sig); err != nil {
			continue
		}

		if sig.Type == "register" {
			clientID = sig.From
			clientsMu.Lock()
			clients[clientID] = conn
			clientsMu.Unlock()
			log.Printf("✅ Registered: %s", clientID)
			continue
		}

		// FORWARDING LOGIC
		if sig.To != "" {
			clientsMu.Lock()
			target, exists := clients[sig.To]
			clientsMu.Unlock()
			if exists {
				target.WriteMessage(websocket.TextMessage, msg)
				log.Printf("➡️ Forwarded %s from %s to %s", sig.Type, sig.From, sig.To)
			} else {
				log.Printf("❌ Target %s not found for %s", sig.To, sig.Type)
			}
		}
	}
}
