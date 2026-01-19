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

// FIX: Root handler to prevent 404 errors on the main URL
func handleHome(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Ayy ToTo Signaling Server is Live!"))
}

// FIX: Ping handler specifically for Cron-job.org or UptimeRobot
func handlePing(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("pong"))
}

func handleSignaling(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
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
		log.Println("Peer disconnected")
	}()

	log.Println("New peer connected to signaling server")

	for {
		mt, message, err := conn.ReadMessage()
		if err != nil {
			break
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

	// Routes
	http.HandleFunc("/", handleHome)     // Prevents 404 at chakra-1zg5.onrender.com/
	http.HandleFunc("/ping", handlePing) // Use this for your Cron-job
	http.HandleFunc("/ws", handleSignaling)

	log.Printf("Signaling server starting on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
