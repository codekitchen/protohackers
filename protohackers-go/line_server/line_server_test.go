package line_server

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"net"
	"testing"
	"time"
)

const testAddr = ":1338"
const waitTimeout = time.Second * 5

func TestLineEcho(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go runTestServer(t, ctx)
	conn, err := waitForServer()
	if err != nil {
		t.Fatal("could not connect to server", err)
	}

	want := []byte("hello")
	conn.Write([]byte("hello\n"))
	scanner := bufio.NewScanner(conn)
	scanner.Scan()
	err = scanner.Err()

	if err != nil {
		t.Errorf("response error: %o", err)
	}
	got := scanner.Bytes()

	if !bytes.Equal(got, want) {
		t.Errorf("got %q, want %q", got, want)
	}
}

func runTestServer(t *testing.T, ctx context.Context) {
	err := ListenAndServe(ctx, testAddr, handleLine)
	if err != nil {
		t.Error(err)
	}
}

func waitForServer() (net.Conn, error) {
	startTime := time.Now()
	for {
		conn, err := net.Dial("tcp4", testAddr)
		if err == nil {
			return conn, nil
		}

		if time.Since(startTime) >= waitTimeout {
			return nil, fmt.Errorf("timed out waiting for server to start on %s", testAddr)
		}
		time.Sleep(50 * time.Millisecond)
	}
}

func handleLine(line []byte) []byte {
	return line
}
