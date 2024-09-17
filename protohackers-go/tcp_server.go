package protohackersgo

import (
	"context"
	"errors"
	"log/slog"
	"net"
)

type Handler func(ctx context.Context, c net.Conn, logger *slog.Logger)

func ListenAndServe(ctx context.Context, addr string, handler Handler) error {
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
		go handler(ctx, c, logger)
	}
}
