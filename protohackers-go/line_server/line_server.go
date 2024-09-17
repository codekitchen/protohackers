package line_server

import (
	"bufio"
	"context"
	"errors"
	"log/slog"
	"net"
)

type LineHandler func([]byte) []byte

func ListenAndServe(ctx context.Context, addr string, handler LineHandler) error {
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
		go handleConn(ctx, c, handler, logger)
	}
}

func handleConn(_ context.Context, c net.Conn, handler LineHandler, logger *slog.Logger) {
	defer c.Close()
	logger = logger.With("remote_addr", c.RemoteAddr())
	scanner := bufio.NewScanner(c)

	for scanner.Scan() {
		line := scanner.Bytes()
		logger.Debug("Received line", "length", len(line))
		res := handler(line)
		_, err := c.Write(res)
		if err == nil {
			_, err = c.Write([]byte("\n"))
		}
		if err != nil {
			logger.Error("Failed to write response", "error", err)
			return
		}
		logger.Debug("Sent response", "length", len(res))
	}

	if err := scanner.Err(); err != nil {
		logger.Error("Scanner error", "error", err)
	}

	logger.Info("Connection closed")
}
