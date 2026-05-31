package main

import (
	"fmt"

	"code.byted.org/data-speech/wsclientsdk/protogen/common/event"
	"code.byted.org/data-speech/wsclientsdk/protogen/common/rpcmeta"
	"code.byted.org/data-speech/wsclientsdk/protogen/products/understanding/ast"
	"code.byted.org/data-speech/wsclientsdk/protogen/products/understanding/base"
)

const audioChunkBytes = 16000 * 2 * 80 / 1000

type audioStream struct {
	started bool
	buffer  []byte
}

func (s *audioStream) reset() {
	s.started = false
	s.buffer = s.buffer[:0]
}

func (c *astClient) sendAudio(data []byte, timestamp int) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn == nil {
		return fmt.Errorf("session not started")
	}
	if len(data) == 0 {
		return nil
	}

	c.audioStream.buffer = append(c.audioStream.buffer, data...)
	if !c.audioStream.started {
		return nil
	}
	return c.flushAudioChunksLocked(false)
}

func (c *astClient) markSessionStarted() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.audioStream.started = true
	return c.flushAudioChunksLocked(false)
}

func (c *astClient) flushAudioChunksLocked(flushRemainder bool) error {
	req := &ast.TranslateRequest{
		RequestMeta: &rpcmeta.RequestMeta{SessionID: c.sessionID},
		Event:       event.Type_TaskRequest,
	}

	for len(c.audioStream.buffer) >= audioChunkBytes {
		req.SourceAudio = &base.Audio{BinaryData: append([]byte(nil), c.audioStream.buffer[:audioChunkBytes]...)}
		if err := send(c.conn, req); err != nil {
			return fmt.Errorf("send audio: %w", err)
		}
		c.audioStream.buffer = c.audioStream.buffer[audioChunkBytes:]
	}

	if flushRemainder && len(c.audioStream.buffer) > 0 {
		req.SourceAudio = &base.Audio{BinaryData: append([]byte(nil), c.audioStream.buffer...)}
		if err := send(c.conn, req); err != nil {
			return fmt.Errorf("send audio remainder: %w", err)
		}
		c.audioStream.buffer = c.audioStream.buffer[:0]
	}
	return nil
}
