package main

import (
	"bufio"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"sync"
)

type output struct {
	mu      sync.Mutex
	encoder *json.Encoder
}

func main() {
	out := &output{encoder: json.NewEncoder(os.Stdout)}
	client := newASTClient(out)

	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 64*1024), 8*1024*1024)

	for scanner.Scan() {
		var cmd command
		if err := json.Unmarshal(scanner.Bytes(), &cmd); err != nil {
			out.send(helperEvent{Type: "error", Message: fmt.Sprintf("invalid command: %v", err)})
			continue
		}

		switch cmd.Type {
		case "start":
			if err := client.start(cmd); err != nil {
				out.send(helperEvent{Type: "error", Message: err.Error()})
			}
		case "audio":
			data, err := base64.StdEncoding.DecodeString(cmd.DataBase64)
			if err != nil {
				out.send(helperEvent{Type: "error", Message: fmt.Sprintf("decode audio: %v", err)})
				continue
			}
			if err := client.sendAudio(data, cmd.TimestampMilliseconds); err != nil {
				out.send(helperEvent{Type: "error", Message: err.Error()})
			}
		case "finish", "stop":
			if err := client.finish(); err != nil {
				out.send(helperEvent{Type: "error", Message: err.Error()})
			}
			return
		default:
			out.send(helperEvent{Type: "error", Message: "unknown command: " + cmd.Type})
		}
	}

	if err := scanner.Err(); err != nil {
		out.send(helperEvent{Type: "error", Message: fmt.Sprintf("read stdin: %v", err)})
	}
	_ = client.finish()
}

func (o *output) send(evt helperEvent) {
	o.mu.Lock()
	defer o.mu.Unlock()
	if err := o.encoder.Encode(evt); err != nil {
		fmt.Fprintf(os.Stderr, "encode event: %v\n", err)
	}
}

func (o *output) logf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
}
