package main

import (
	"context"
	"encoding/json"
	"fmt"
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
	fmt.Printf("got `%s`\n", line)

	var msg request
	err := json.Unmarshal(line, &msg)
	if err != nil || msg.Method != "isPrime" || msg.Number == nil {
		return errorResponse
	}

	res := response{Method: "isPrime", IsPrime: isPrime(*msg.Number)}

	resMsg, err := json.Marshal(res)
	if err != nil {
		return errorResponse
	}
	return resMsg
}

func main() {
	ctx := context.Background()
	err := line_server.ListenAndServe(ctx, ":1337", handleLine)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s\n", err)
		os.Exit(1)
	}
}
