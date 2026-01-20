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
	Type      string      `json:"type"`
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

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("Chakra Signaling Server is Running"))
	})
	http.HandleFunc("/ws", handleWebSocket)

	log.Printf("Signaling Server starting on 0.0.0.0:%s", port)
	if err := http.ListenAndServe("0.0.0.0:"+port, nil); err != nil {
		log.Fatal(err)
	}
}

func handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, _ := upgrader.Upgrade(w, r, nil)
	defer conn.Close()
	var clientID string

	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			break
		}
		var sig SignalMessage
		json.Unmarshal(msg, &sig)

		if sig.Type == "register" {
			clientID = sig.From
			clientsMu.Lock()
			clients[clientID] = conn
			clientsMu.Unlock()
			log.Printf("Registered: %s", clientID)
			continue
		}

		if sig.To != "" {
			clientsMu.Lock()
			if target, ok := clients[sig.To]; ok {
				target.WriteMessage(websocket.TextMessage, msg)
			}
			clientsMu.Unlock()
		}
	}
}
