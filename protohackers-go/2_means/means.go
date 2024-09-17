package main

import (
	"context"
	"encoding/binary"
	"errors"
	"io"
	"log/slog"
	"net"
	"os"
)

func main() {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug})))
	err := ListenAndServe(context.Background(), ":1337")
	if err != nil {
		slog.Error("Failed to start server", "error", err)
		os.Exit(1)
	}
}

func ListenAndServe(ctx context.Context, addr string) error {
	logger := slog.Default()

	srv, err := net.Listen("tcp", addr)
	if err != nil {
		logger.Error("Failed to start server", "error", err)
		return err
	}
	defer srv.Close()

	logger.Info("Server started", "address", addr)

	go func() {
		<-ctx.Done()
		logger.Info("Shutting down server")
		srv.Close()
	}()

	for {
		c, err := srv.Accept()
		if errors.Is(err, net.ErrClosed) {
			logger.Info("Server closed")
			return nil
		}
		if err != nil {
			logger.Error("Failed to accept connection", "error", err)
			return err
		}
		logger.Info("New connection accepted", "remote_addr", c.RemoteAddr())
		go handleConn(ctx, c, logger)
	}
}

func handleConn(_ context.Context, c net.Conn, logger *slog.Logger) {
	defer c.Close()
	logger = logger.With("remote_addr", c.RemoteAddr())
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

type price struct {
	timestamp int32
	price     int32
}

type session struct {
	prices []price
}

func (s *session) insert(timestamp, val int32) {
	s.prices = append(s.prices, price{timestamp, val})
}

func (s *session) query(min, max int32) int32 {
	var sum int64 = 0
	var count int64 = 0
	for _, p := range s.prices {
		if p.timestamp >= min && p.timestamp <= max {
			sum += int64(p.price)
			count++
		}
	}
	if count > 0 {
		return int32(sum / count)
	}
	return 0
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
