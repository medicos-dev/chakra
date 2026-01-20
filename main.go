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
	upgrader  = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool { return true },
	}
)

type SignalMessage struct {
	Type      string      `json:"type"` // offer, answer, candidate, register
	From      string      `json:"from"` // Sender ID
	To        string      `json:"to"`   // Recipient ID
	SDP       interface{} `json:"sdp,omitempty"`
	Candidate interface{} `json:"candidate,omitempty"`
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "10000"
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("Chakra Signaling Server Active"))
	})
	http.HandleFunc("/ws", handleWebSocket)

	log.Printf("Server starting on 0.0.0.0:%s", port)
	if err := http.ListenAndServe("0.0.0.0:"+port, nil); err != nil {
		log.Fatal(err)
	}
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
			log.Printf("Registered Device: %s", clientID)
			continue
		}

		// ROUTING LOGIC: Forward Offer, Answer, AND Candidates
		if sig.To != "" {
			clientsMu.Lock()
			target, exists := clients[sig.To]
			clientsMu.Unlock()

			if exists {
				target.WriteMessage(websocket.TextMessage, msg)
			}
		}
	}

	clientsMu.Lock()
	delete(clients, clientID)
	clientsMu.Unlock()
}
