package line_server

import (
	"bufio"
	"context"
	"errors"
	"net"
)

type LineHandler func([]byte) []byte

func ListenAndServe(ctx context.Context, addr string, handler LineHandler) error {
	srv, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	defer srv.Close()

	// watch for closed context
	ctx, cancel := context.WithCancel(ctx)
	defer cancel() // make sure the following never lives forever
	go func() {
		<-ctx.Done()
		srv.Close()
	}()

	for {
		c, err := srv.Accept()
		if errors.Is(err, net.ErrClosed) {
			return nil
		}
		if err != nil {
			return err
		}
		go handleConn(ctx, c, handler)
	}
}

func handleConn(_ context.Context, c net.Conn, handler LineHandler) {
	defer c.Close()
	scanner := bufio.NewScanner(c)

	for scanner.Scan() {
		line := scanner.Bytes()
		res := handler(line)
		c.Write(res)
		c.Write([]byte("\n"))
	}
}
