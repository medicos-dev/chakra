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

var (
	clients = make(map[*websocket.Conn]bool)
	mu      sync.Mutex
)

func handleSignaling(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
		return // MUST return here so we don't use 'w' anymore
	}
	defer func() {
		mu.Lock()
		delete(clients, conn)
		mu.Unlock()
		conn.Close()
	}()

	// IMPORTANT: Add the connection to our client list
	mu.Lock()
	clients[conn] = true
	mu.Unlock()

	log.Println("New peer connected to signaling server")

	for {
		mt, message, err := conn.ReadMessage()
		if err != nil {
			log.Println("Read error:", err)
			break
		}
		// Relay the message to all other connected peers (Phone <-> Laptop)
		broadcast(mt, message, conn)
	}
}

func broadcast(mt int, msg []byte, sender *websocket.Conn) {
	mu.Lock()
	defer mu.Unlock()
	for client := range clients {
		if client != sender {
			err := client.WriteMessage(mt, msg)
			if err != nil {
				log.Println("Broadcast error:", err)
				client.Close()
				delete(clients, client)
			}
		}
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/ws", handleSignaling)
	log.Printf("Signaling server starting on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
