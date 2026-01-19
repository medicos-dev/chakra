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

// Thread-safe map to track all connected devices (Phone & Laptop)
var (
	clients = make(map[*websocket.Conn]bool)
	mu      sync.Mutex
)

func handleSignaling(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
		return // Exit immediately to avoid "hijacked connection" error
	}

	// Register the new device (Phone or Laptop)
	mu.Lock()
	clients[conn] = true
	mu.Unlock()
	log.Println("New peer connected to signaling server")

	defer func() {
		mu.Lock()
		delete(clients, conn)
		mu.Unlock()
		conn.Close()
		log.Println("Peer disconnected")
	}()

	for {
		mt, message, err := conn.ReadMessage()
		if err != nil {
			break
		}
		// RELAY: Send the message to the OTHER device
		broadcast(mt, message, conn)
	}
}

func broadcast(mt int, msg []byte, sender *websocket.Conn) {
	mu.Lock()
	defer mu.Unlock()
	for client := range clients {
		if client != sender {
			// This sends the Phone's offer to the Laptop, and vice versa
			client.WriteMessage(mt, msg)
		}
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "10000"
	}

	http.HandleFunc("/ws", handleSignaling)
	log.Printf("Signaling server starting on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
