package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

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
	Type    string `json:"type"`
	Target  string `json:"target"`
	Sender  string `json:"sender"`
	Payload string `json:"payload"`
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

	// KEEP-ALIVE: Prevents Render from closing idle connections
	conn.SetPongHandler(func(string) error { return nil })
	go func() {
		ticker := time.NewTicker(20 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}()

	var currentClientID string

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
			continue
		}

		if sig.Type == "register" {
			currentClientID = sig.Target
			clientsMu.Lock()
			clients[currentClientID] = conn
			clientsMu.Unlock()
			log.Printf("✅ Registered: %s", currentClientID)
			continue
		}

		if sig.Target != "" {
			clientsMu.Lock()
			targetConn, exists := clients[sig.Target]
			clientsMu.Unlock()

			if exists {
				sig.Sender = currentClientID
				forwardMsg, _ := json.Marshal(sig)
				targetConn.WriteMessage(websocket.TextMessage, forwardMsg)
				log.Printf("➡️ %s: %s -> %s", sig.Type, currentClientID, sig.Target)
			}
		}
	}
}
