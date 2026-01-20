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

// Root handler for health checks and Render logs
func handleHome(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Ayy ToTo Signaling Server is LIVE"))
}

func handleSignaling(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Upgrade error: %v", err)
		return
	}

	// Log the connection event
	log.Printf("NEW PEER CONNECTED: %s", r.RemoteAddr)

	mu.Lock()
	clients[conn] = true
	mu.Unlock()

	defer func() {
		mu.Lock()
		delete(clients, conn)
		mu.Unlock()
		log.Printf("PEER DISCONNECTED: %s", r.RemoteAddr)
		conn.Close()
	}()

	for {
		mt, message, err := conn.ReadMessage()
		if err != nil {
			break
		}

		// Filter out internal 'ping' heartbeats from the broadcast
		if string(message) == `{"type":"ping"}` {
			continue
		}

		broadcast(mt, message, conn)
	}
}

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

	http.HandleFunc("/", handleHome)
	http.HandleFunc("/ws", handleSignaling)

	log.Printf("Server starting on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
