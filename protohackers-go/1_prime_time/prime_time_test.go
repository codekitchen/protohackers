package main

import (
	"bytes"
	"testing"
)

func TestPrimeMessages(t *testing.T) {
	cases := []struct{ input, output []byte }{
		{[]byte(`{"method":"isPrime","number":4}`), []byte(`{"method":"isPrime","prime":false}`)},
		{[]byte(`{"method":"isPrime","number":5}`), []byte(`{"method":"isPrime","prime":true}`)},
		{[]byte(`{"method":"isPrime","number":-4}`), []byte(`{"method":"isPrime","prime":false}`)},
		{[]byte(`{"method":"isPrime","number":4.3}`), []byte(`{"method":"isPrime","prime":false}`)},
		{[]byte(`{"method":"isPrime",`), []byte(`go away`)},
		{[]byte(`{"method":"isPrime"}`), []byte(`go away`)},
		{[]byte(`{"method":"isPrime","number":"hi"}`), []byte(`go away`)},
		{[]byte(`{"method":"other","number":4}`), []byte(`go away`)},
		{[]byte(`{"number":4}`), []byte(`go away`)},
	}
	for _, test := range cases {
		t.Run(string(test.input), func(t *testing.T) {
			got := handleLine(test.input)
			if !bytes.Equal(got, test.output) {
				t.Errorf("for %q got %q, want %q", test.input, got, test.output)
			}
		})
	}
}
