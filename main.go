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

// Map to store active connections by their Device ID
var (
	clients = make(map[string]*websocket.Conn)
	mu      sync.Mutex
)

type SignalMessage struct {
	Type string `json:"type"`
	From string `json:"from"` // Who sent it
	To   string `json:"to"`   // Who should get it
}

func handleHome(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("Ayy ToTo Multi-Session Server Active"))
}

func handleSignaling(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}

	var currentDeviceID string

	defer func() {
		mu.Lock()
		delete(clients, currentDeviceID)
		mu.Unlock()
		conn.Close()
		log.Printf("Disconnected: %s", currentDeviceID)
	}()

	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			break
		}

		var msg map[string]interface{}
		json.Unmarshal(message, &msg)

		// 1. Register device on first message
		fromID, _ := msg["from"].(string)
		if fromID != "" && currentDeviceID == "" {
			currentDeviceID = fromID
			mu.Lock()
			clients[currentDeviceID] = conn
			mu.Unlock()
			log.Printf("Registered Device: %s", currentDeviceID)
		}

		// 2. Targeted Routing
		targetID, _ := msg["to"].(string)
		if targetID != "" {
			mu.Lock()
			if targetConn, exists := clients[targetID]; exists {
				targetConn.WriteMessage(websocket.TextMessage, message)
			}
			mu.Unlock()
		}
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "10000"
	}

	http.HandleFunc("/", handleHome)
	http.HandleFunc("/ws", handleSignaling)

	log.Printf("Server starting on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
