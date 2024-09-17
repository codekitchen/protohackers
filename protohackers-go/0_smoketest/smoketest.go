package main

import (
	"context"
	"fmt"
	"net"
	"os"
)

func handle(_ context.Context, c net.Conn) {
	defer c.Close()
	buf := make([]byte, 1024)

	for {
		ln, err := c.Read(buf)
		if err != nil {
			fmt.Fprintf(os.Stderr, "%s\n", err)
			return
		}
		fmt.Printf("received %d bytes on %v %q\n", ln, c.RemoteAddr(), buf[0:ln])

		c.Write(buf[0:ln])
	}
}

func run(ctx context.Context) error {
	srv, err := net.Listen("tcp4", ":1337")
	if err != nil {
		return err
	}
	defer srv.Close()

	for {
		c, err := srv.Accept()
		if err != nil {
			return err
		}
		go handle(ctx, c)
	}
}

func main() {
	ctx := context.Background()
	if err := run(ctx); err != nil {
		fmt.Fprintf(os.Stderr, "%s\n", err)
		os.Exit(1)
	}
}
