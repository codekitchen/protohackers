package line_server

import (
	"bufio"
	"context"
	"log/slog"
	"net"
	protohackersgo "protohackers-go"
)

type LineHandler func([]byte) []byte

func ListenAndServe(ctx context.Context, addr string, handler LineHandler) error {
	return protohackersgo.ListenAndServe(ctx, addr, func(ctx context.Context, c net.Conn, logger *slog.Logger) {
		handleConn(ctx, c, handler, logger)
	})
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
