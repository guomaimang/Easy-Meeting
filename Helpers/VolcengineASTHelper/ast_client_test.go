package main

import (
	"bytes"
	"encoding/json"
	"io"
	"testing"

	"code.byted.org/data-speech/wsclientsdk/protogen/common/event"
	"code.byted.org/data-speech/wsclientsdk/protogen/products/understanding/ast"
)

func TestSourceEndDoesNotEmitFinalWithPreviousTranslation(t *testing.T) {
	var buffer bytes.Buffer
	client := newASTClient(&output{encoder: json.NewEncoder(&buffer)})
	client.sourceLanguage = "en"
	client.targetLanguage = "zh"

	client.handleResponse(&ast.TranslateResponse{Event: event.Type_SourceSubtitleStart})
	client.handleResponse(&ast.TranslateResponse{Event: event.Type_SourceSubtitleResponse, Text: "Hello"})
	client.handleResponse(&ast.TranslateResponse{Event: event.Type_SourceSubtitleEnd, Text: "Hello."})
	client.handleResponse(&ast.TranslateResponse{Event: event.Type_TranslationSubtitleStart})
	client.handleResponse(&ast.TranslateResponse{Event: event.Type_TranslationSubtitleResponse, Text: "你好"})
	client.handleResponse(&ast.TranslateResponse{Event: event.Type_TranslationSubtitleEnd, Text: "。"})

	client.handleResponse(&ast.TranslateResponse{Event: event.Type_SourceSubtitleStart})
	client.handleResponse(&ast.TranslateResponse{Event: event.Type_SourceSubtitleResponse, Text: "Okay"})
	client.handleResponse(&ast.TranslateResponse{Event: event.Type_SourceSubtitleEnd, Text: "."})

	events := decodeSubtitleEvents(t, buffer.Bytes())
	finalCount := 0
	for _, evt := range events {
		if evt.IsFinal {
			finalCount++
		}
	}
	if finalCount != 1 {
		t.Fatalf("final event count = %d, want 1; events = %+v", finalCount, events)
	}
}

func TestAudioIsBufferedBeforeSessionStarted(t *testing.T) {
	client := newASTClient(&output{encoder: json.NewEncoder(io.Discard)})
	client.audioBuffer = append(client.audioBuffer, make([]byte, audioChunkBytes+16)...)

	if len(client.audioBuffer) != audioChunkBytes+16 {
		t.Fatalf("buffered bytes = %d, want %d", len(client.audioBuffer), audioChunkBytes+16)
	}
}

func decodeSubtitleEvents(t *testing.T, data []byte) []helperEvent {
	t.Helper()

	decoder := json.NewDecoder(bytes.NewReader(data))
	var events []helperEvent
	for {
		var evt helperEvent
		if err := decoder.Decode(&evt); err != nil {
			if err == io.EOF {
				break
			}
			t.Fatalf("decode helper event: %v", err)
		}
		if evt.Type == "subtitle" {
			events = append(events, evt)
		}
	}
	return events
}
