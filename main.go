package main

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/pion/webrtc/v3"
)

// Use the Render URL you provided
const SignalingURL = "wss://chakra-1zg5.onrender.com/ws"
const GatewayID = "laptop_gateway"

// Structs for signaling
type SignalMessage struct {
	Type      string      `json:"type"`
	From      string      `json:"from"`
	To        string      `json:"to"`
	SDP       interface{} `json:"sdp,omitempty"`
	Candidate interface{} `json:"candidate,omitempty"`
}

var (
	sessions = make(map[string]*webrtc.PeerConnection)
	mu       sync.Mutex
)

func main() {
	log.Println("Starting Chakra Gateway...")
	for {
		err := runGateway()
		log.Printf("Gateway disconnected: %v. Reconnecting in 5s...", err)
		time.Sleep(5 * time.Second)
	}
}

func runGateway() error {
	conn, _, err := websocket.DefaultDialer.Dial(SignalingURL, nil)
	if err != nil {
		return err
	}
	defer conn.Close()

	// Register
	conn.WriteJSON(map[string]string{"type": "register", "from": GatewayID})
	log.Println("Registered as", GatewayID)

	// Keep-Alive Loop
	go func() {
		for {
			time.Sleep(30 * time.Second)
			conn.WriteJSON(map[string]string{"type": "ping", "from": GatewayID})
		}
	}()

	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			return err
		}

		var sig SignalMessage
		if err := json.Unmarshal(msg, &sig); err != nil {
			continue
		}

		switch sig.Type {
		case "offer":
			go handleOffer(conn, sig)
		case "candidate":
			handleCandidate(sig)
		}
	}
}

func handleOffer(ws *websocket.Conn, msg SignalMessage) {
	mu.Lock()
	if old, ok := sessions[msg.From]; ok {
		old.Close()
	}
	mu.Unlock()

	config := webrtc.Configuration{
		ICEServers: []webrtc.ICEServer{{URLs: []string{"stun:stun.l.google.com:19302"}}},
	}

	pc, _ := webrtc.NewPeerConnection(config)

	mu.Lock()
	sessions[msg.From] = pc
	mu.Unlock()

	// ---------------------------------------------------------
	// DATA CHANNEL HANDLER (The "VPN" Traffic Logic)
	// ---------------------------------------------------------
	pc.OnDataChannel(func(d *webrtc.DataChannel) {
		log.Printf("VPN Tunnel Opened for %s", msg.From)

		d.OnOpen(func() {
			log.Printf("Data Channel %s : OPEN", d.Label())
		})

		d.OnMessage(func(m webrtc.DataChannelMessage) {
			// THIS IS WHERE RAW IP PACKETS ARRIVE
			// Currently, we just log the size to prove it works.
			// To make "whatismyip" work, we would need to write these bytes
			// to a virtual network interface (TUN) on your laptop.

			packetSize := len(m.Data)
			if packetSize > 0 {
				// LOGIC: Just echo it back for now to test "Download Speed"
				// In production, you parse the IP header here.
				// log.Printf("Received packet: %d bytes", packetSize)

				// Send a dummy "Ack" so your phone sees download activity
				// d.Send(m.Data)
			}
		})
	})

	// Handle ICE Candidates
	pc.OnICECandidate(func(c *webrtc.ICECandidate) {
		if c == nil {
			return
		}
		resp := SignalMessage{
			Type: "candidate", From: GatewayID, To: msg.From,
			Candidate: c.ToJSON(),
		}
		bytes, _ := json.Marshal(resp)
		ws.WriteMessage(websocket.TextMessage, bytes)
	})

	// Handle SDP (Fixing the panic you saw earlier)
	var sdpStr string
	switch v := msg.SDP.(type) {
	case string:
		sdpStr = v
	case map[string]interface{}:
		if s, ok := v["sdp"].(string); ok {
			sdpStr = s
		}
	}

	pc.SetRemoteDescription(webrtc.SessionDescription{Type: webrtc.SDPTypeOffer, SDP: sdpStr})
	answer, _ := pc.CreateAnswer(nil)
	pc.SetLocalDescription(answer)

	resp := SignalMessage{
		Type: "answer", From: GatewayID, To: msg.From,
		SDP: map[string]string{"type": "answer", "sdp": answer.SDP},
	}
	bytes, _ := json.Marshal(resp)
	ws.WriteMessage(websocket.TextMessage, bytes)
}

func handleCandidate(msg SignalMessage) {
	mu.Lock()
	pc, ok := sessions[msg.From]
	mu.Unlock()
	if !ok {
		return
	}

	if candMap, ok := msg.Candidate.(map[string]interface{}); ok {
		sdp := candMap["candidate"].(string)
		mid := candMap["sdpMid"].(string)
		idx := uint16(candMap["sdpMLineIndex"].(float64))
		pc.AddICECandidate(webrtc.ICECandidateInit{Candidate: sdp, SDPMid: &mid, SDPMLineIndex: &idx})
	}
}
