package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"os"
	"protohackers-go/line_server"
)

type request struct {
	Method string   `json:"method"`
	Number *float64 `json:"number"`
}
type response struct {
	Method  string `json:"method"`
	IsPrime bool   `json:"prime"`
}

// {"method":"isPrime","number":123}
// {"method":"isPrime","prime":false}

func isPrime(n float64) bool {
	if n < 2 {
		return false
	}
	i := int64(n)
	if float64(i) != n {
		return false
	}

	for c := int64(2); c < i; c++ {
		if i%c == 0 {
			return false
		}
	}
	return true
}

var errorResponse = []byte("go away")

func handleLine(line []byte) []byte {
	var msg request
	err := json.Unmarshal(line, &msg)
	if err == nil && msg.Method == "isPrime" && msg.Number != nil {
		resMsg, err := json.Marshal(response{Method: "isPrime", IsPrime: isPrime(*msg.Number)})
		if err == nil {
			return resMsg
		}
	}

	return errorResponse
}

func main() {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug})))
	ctx := context.Background()
	err := line_server.ListenAndServe(ctx, ":1337", handleLine)
	if err != nil {
		slog.Error("Failed to start server", "error", err)
		os.Exit(1)
	}
}
