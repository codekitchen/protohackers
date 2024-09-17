package main

import (
	"context"
	"encoding/binary"
	"errors"
	"io"
	"log/slog"
	"net"
	"os"
	protohackersgo "protohackers-go"
)

func main() {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug})))
	err := protohackersgo.ListenAndServe(context.Background(), ":1337", handleConn)
	if err != nil {
		slog.Error("Failed to start server", "error", err)
		os.Exit(1)
	}
}

func handleConn(_ context.Context, c net.Conn, logger *slog.Logger) {
	defer c.Close()
	logger = logger.With("remote_addr", c.RemoteAddr())
	logger.Info("New connection accepted")
	s := session{}

	for {
		msg := make([]byte, 9)
		_, err := io.ReadFull(c, msg)

		if err != nil {
			if !errors.Is(err, io.EOF) {
				logger.Error("Failed to read message", "error", err)
			}
			break
		}

		req := parseRequest(msg)
		logger.Debug("Received request", "method", req.Method, "a", req.A, "b", req.B)
		switch req.Method {
		case 'I':
			s.insert(req.A, req.B)
		case 'Q':
			res := s.query(req.A, req.B)
			logger.Debug("Sending response", "response", res)
			c.Write(makeResponse(res))
		}
	}
	logger.Info("Connection closed")
}

type request struct {
	Method byte
	A      int32
	B      int32
}

// parse a request from a 9-byte message
func parseRequest(msg []byte) (req request) {
	req.Method = msg[0]
	req.A = int32(binary.BigEndian.Uint32(msg[1:5]))
	req.B = int32(binary.BigEndian.Uint32(msg[5:9]))
	return
}

func makeResponse(i int32) []byte {
	msg := make([]byte, 4)
	binary.BigEndian.PutUint32(msg, uint32(i))
	return msg
}
