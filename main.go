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

// FIX: Root handler for Cron-job.org / browser checks
func handleHome(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Ayy ToTo Signaling Server Live"))
}

func handleSignaling(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}

	mu.Lock()
	clients[conn] = true
	mu.Unlock()

	defer func() {
		mu.Lock()
		delete(clients, conn)
		mu.Unlock()
		conn.Close()
	}()

	for {
		mt, message, err := conn.ReadMessage()
		if err != nil {
			break
		}

		// Ignore keep-alive pings to save bandwidth
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

	http.HandleFunc("/", handleHome) // PING THIS WITH CRON-JOB
	http.HandleFunc("/ws", handleSignaling)

	log.Printf("Server starting on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
