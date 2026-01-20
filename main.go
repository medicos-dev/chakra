package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"sync"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

// Map to store active connections: DeviceID -> WebSocket Connection
var (
	clients = make(map[string]*websocket.Conn)
	mu      sync.Mutex
)

// Standard message format for routing
type SignalMessage struct {
	Type string `json:"type"`
	From string `json:"from"` // Sender ID (e.g., Phone_123)
	To   string `json:"to"`   // Target ID (e.g., laptop_gateway)
}

func handleHome(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("Ayy ToTo Signaling Server is Running..."))
}

func handleSignaling(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade Error:", err)
		return
	}

	var currentDeviceID string

	// Cleanup on disconnect
	defer func() {
		if currentDeviceID != "" {
			mu.Lock()
			delete(clients, currentDeviceID)
			mu.Unlock()
			log.Printf("Disconnected & Removed: %s", currentDeviceID)
		}
		conn.Close()
	}()

	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			break
		}

		var msg map[string]interface{}
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Println("JSON Unmarshal Error:", err)
			continue
		}

		// 1. Registration: Map the connection to the Device ID
		if from, ok := msg["from"].(string); ok && from != "" {
			if currentDeviceID == "" {
				currentDeviceID = from
				mu.Lock()
				clients[currentDeviceID] = conn
				mu.Unlock()
				log.Printf("Device Registered: %s", currentDeviceID)
			}
		}

		// 2. Routing: Forward message to the specific target
		if to, ok := msg["to"].(string); ok && to != "" {
			mu.Lock()
			targetConn, exists := clients[to]
			mu.Unlock()

			if exists {
				// Forward the raw message exactly as received
				if err := targetConn.WriteMessage(websocket.TextMessage, message); err != nil {
					log.Printf("Failed to send to %s: %v", to, err)
				}
			} else {
				// Optional: Log if target not found (noisy for broadcasts, useful for P2P)
				// log.Printf("Target %s not found", to)
			}
		}
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "10000" // Default for Render
	}

	http.HandleFunc("/", handleHome)
	http.HandleFunc("/ws", handleSignaling)

	log.Printf("Signaling Server starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
