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

// SignalMessage matched exactly with Gateway and Flutter Client
type SignalMessage struct {
	Type    string `json:"type"`    // register, offer, answer, candidate
	Target  string `json:"target"`  // Who should receive this
	Sender  string `json:"sender"`  // Who sent this
	Payload string `json:"payload"` // The actual SDP or Candidate string
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
		log.Println("Upgrade error:", err)
		return
	}

	var currentClientID string

	// Ensure cleanup when connection closes
	defer func() {
		if currentClientID != "" {
			clientsMu.Lock()
			delete(clients, currentClientID)
			clientsMu.Unlock()
			log.Printf("❌ Disconnected: %s", currentClientID)
		}
		conn.Close()
	}()

	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			break
		}

		var sig SignalMessage
		if err := json.Unmarshal(msg, &sig); err != nil {
			log.Println("Unmarshal error:", err)
			continue
		}

		// Handle Registration
		if sig.Type == "register" {
			currentClientID = sig.Target // In register, Target is the ID of the sender
			clientsMu.Lock()
			clients[currentClientID] = conn
			clientsMu.Unlock()
			log.Printf("✅ Registered: %s", currentClientID)
			continue
		}

		// Handle Forwarding (Offer, Answer, Candidate)
		if sig.Target != "" {
			clientsMu.Lock()
			targetConn, exists := clients[sig.Target]
			clientsMu.Unlock()

			if exists {
				// We attach the sender's ID so the target knows who to reply to
				sig.Sender = currentClientID
				forwardMsg, _ := json.Marshal(sig)

				err = targetConn.WriteMessage(websocket.TextMessage, forwardMsg)
				if err != nil {
					log.Printf("Error forwarding to %s: %v", sig.Target, err)
				} else {
					log.Printf("➡️ Forwarded %s from %s to %s", sig.Type, currentClientID, sig.Target)
				}
			} else {
				log.Printf("⚠️ Target %s not found for %s", sig.Target, sig.Type)
			}
		}
	}
}
