package main

import (
	"bytes"
	"testing"
)

func TestParseRequest(t *testing.T) {
	msg := []byte{0x49, 0x00, 0x00, 0x30, 0x39, 0x00, 0x00, 0x00, 0x65}
	req := parseRequest(msg)
	if req.Method != 'I' {
		t.Errorf("expected method 0, got %d", req.Method)
	}
	if req.A != 12345 {
		t.Errorf("expected A 1, got %d", req.A)
	}
	if req.B != 101 {
		t.Errorf("expected B 2, got %d", req.B)
	}
}

func TestMakeResponse(t *testing.T) {
	msg := makeResponse(12345)
	if !bytes.Equal(msg, []byte{0x00, 0x00, 0x30, 0x39}) {
		t.Errorf("expected 12345, got %o", msg)
	}
}

func TestSession(t *testing.T) {
	s := session{}
	s.insert(12345, 101)
	s.insert(12346, 102)
	s.insert(12347, 100)
	s.insert(40960, 5)
	got := s.query(12288, 16384)

	want := int32(101)
	if got != want {
		t.Errorf("expected %d, got %d", want, got)
	}
}
