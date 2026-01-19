package main

import (
	"log"
	"net/http"
	"os"
	"sync"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

// Simple peer-to-peer relay
func handleSignaling(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()

	for {
		mt, message, err := conn.ReadMessage()
		if err != nil {
			break
		}
		// Broadcast to everyone (In a 1:1 VPN, this just sends it to the other peer)
		// For production, you'd use a Map to handle multiple users/rooms
		broadcast(mt, message, conn)
	}
}

var clients = make(map[*websocket.Conn]bool)
var mu sync.Mutex

func broadcast(mt int, msg []byte, sender *websocket.Conn) {
	mu.Lock()
	defer mu.Unlock()
	for client := range clients {
		if client != sender {
			client.WriteMessage(mt, msg)
		}
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "10000"
	}
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		conn, _ := upgrader.Upgrade(w, r, nil)
		mu.Lock()
		clients[conn] = true
		mu.Unlock()
		handleSignaling(w, r)
	})
	log.Printf("Signaling server starting on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
