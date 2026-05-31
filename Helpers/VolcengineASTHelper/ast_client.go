package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"google.golang.org/protobuf/proto"

	"code.byted.org/data-speech/wsclientsdk/protogen/common/event"
	"code.byted.org/data-speech/wsclientsdk/protogen/common/rpcmeta"
	"code.byted.org/data-speech/wsclientsdk/protogen/products/understanding/ast"
	"code.byted.org/data-speech/wsclientsdk/protogen/products/understanding/base"
)

type astClient struct {
	out            *output
	mu             sync.Mutex
	conn           *websocket.Conn
	sessionID      string
	sourceLanguage string
	targetLanguage string
	currentSource  string
	currentTarget  string
	finalEmitted   bool
	audioStream    audioStream
}

func newASTClient(out *output) *astClient {
	return &astClient{out: out}
}

func (c *astClient) start(cmd command) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn != nil {
		return fmt.Errorf("session already started")
	}

	connID := uuid.New().String()
	conn, err := dial(cmd, connID)
	if err != nil {
		return fmt.Errorf("dial volcengine: %w", err)
	}

	c.conn = conn
	c.sessionID = cmd.MeetingID
	if c.sessionID == "" {
		c.sessionID = uuid.New().String()
	}
	c.sourceLanguage = cmd.SourceLanguage
	c.targetLanguage = cmd.TargetLanguage
	if c.sourceLanguage == "" {
		c.sourceLanguage = "auto"
	}
	if c.targetLanguage == "" {
		c.targetLanguage = "zh"
	}
	c.currentSource = ""
	c.currentTarget = ""
	c.finalEmitted = false
	c.audioStream.reset()

	req := &ast.TranslateRequest{
		RequestMeta: &rpcmeta.RequestMeta{SessionID: c.sessionID},
		Event:       event.Type_StartSession,
		User: &base.User{
			Uid:      "easy-meeting",
			Did:      "easy-meeting",
			Platform: "macos",
		},
		SourceAudio: &base.Audio{
			Format:  "wav",
			Codec:   "raw",
			Rate:    16000,
			Bits:    16,
			Channel: 1,
		},
		Request: &ast.ReqParams{
			Mode:           "s2t",
			SourceLanguage: c.sourceLanguage,
			TargetLanguage: c.targetLanguage,
		},
	}

	if err := send(conn, req); err != nil {
		_ = conn.Close()
		c.conn = nil
		return fmt.Errorf("start session: %w", err)
	}

	c.out.send(helperEvent{Type: "status", Message: "session_start_sent"})
	go c.receiveLoop(conn)
	return nil
}

func (c *astClient) finish() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn == nil {
		return nil
	}
	if c.audioStream.started {
		if err := c.flushAudioChunksLocked(true); err != nil {
			return err
		}
	}

	req := &ast.TranslateRequest{
		RequestMeta: &rpcmeta.RequestMeta{SessionID: c.sessionID},
		Event:       event.Type_FinishSession,
	}
	err := send(c.conn, req)
	normalClose(c.conn)
	c.conn = nil
	return err
}

func (c *astClient) receiveLoop(conn *websocket.Conn) {
	for {
		resp := new(ast.TranslateResponse)
		if err := receive(conn, resp); err != nil {
			c.out.send(helperEvent{Type: "error", Message: fmt.Sprintf("receive volcengine: %v", err)})
			return
		}
		if c.handleResponse(resp) {
			return
		}
	}
}

func (c *astClient) handleResponse(resp *ast.TranslateResponse) bool {
	switch resp.GetEvent() {
	case event.Type_SessionStarted:
		if err := c.markSessionStarted(); err != nil {
			c.out.send(helperEvent{Type: "error", Message: err.Error()})
			return true
		}
		c.out.send(helperEvent{Type: "status", Message: "session_started"})
	case event.Type_SessionFailed:
		c.out.send(helperEvent{Type: "error", Message: resp.GetResponseMeta().GetMessage()})
		return true
	case event.Type_SessionCanceled:
		c.out.send(helperEvent{Type: "status", Message: "session_canceled"})
		return true
	case event.Type_SessionFinished:
		c.out.send(helperEvent{Type: "status", Message: "session_finished"})
		return true
	case event.Type_SourceSubtitleStart:
		c.currentSource = ""
		c.logSubtitleEvent("source_start", resp)
		c.out.send(c.subtitleEvent("source_start", resp, "", false))
	case event.Type_SourceSubtitleResponse, event.Type_SourceSubtitleEnd:
		c.currentSource = mergeSubtitleText(c.currentSource, resp.GetText())
		eventType := "source"
		if resp.GetEvent() == event.Type_SourceSubtitleEnd {
			eventType = "source_end"
		}
		c.logSubtitleEvent(eventType, resp)
		c.out.send(c.subtitleEvent(eventType, resp, c.currentSource, false))
	case event.Type_TranslationSubtitleStart:
		c.currentTarget = ""
		c.finalEmitted = false
		c.logSubtitleEvent("translation_start", resp)
		c.out.send(c.subtitleEvent("translation_start", resp, "", false))
	case event.Type_TranslationSubtitleResponse, event.Type_TranslationSubtitleEnd:
		c.currentTarget = mergeSubtitleText(c.currentTarget, resp.GetText())
		isFinal := false
		eventType := "translation"
		if resp.GetEvent() == event.Type_TranslationSubtitleEnd {
			eventType = "translation_end"
			isFinal = c.consumeFinalIfReady()
		}
		c.logSubtitleEvent(eventType, resp)
		c.out.send(c.subtitleEvent(eventType, resp, c.currentTarget, isFinal))
	case event.Type_UsageResponse:
		c.out.logf("usage response: status=%d message=%q", resp.GetResponseMeta().GetStatusCode(), resp.GetResponseMeta().GetMessage())
	}
	return false
}

func (c *astClient) logSubtitleEvent(eventType string, resp *ast.TranslateResponse) {
	c.out.logf(
		"subtitle event: type=%s text_len=%d start=%d end=%d",
		eventType,
		len([]rune(resp.GetText())),
		resp.GetStartTime(),
		resp.GetEndTime(),
	)
}

func (c *astClient) consumeFinalIfReady() bool {
	if c.finalEmitted || strings.TrimSpace(c.currentTarget) == "" {
		return false
	}
	c.finalEmitted = true
	return true
}

func (c *astClient) subtitleEvent(eventType string, resp *ast.TranslateResponse, text string, isFinal bool) helperEvent {
	return helperEvent{
		Type:              eventType,
		Text:              text,
		SourceText:        c.currentSource,
		TranslatedText:    c.currentTarget,
		StartMilliseconds: resp.GetStartTime(),
		EndMilliseconds:   resp.GetEndTime(),
		SourceLanguage:    c.sourceLanguage,
		TargetLanguage:    c.targetLanguage,
		IsInterim:         !isFinal,
		IsFinal:           isFinal,
	}
}

func mergeSubtitleText(current, incoming string) string {
	if incoming == "" {
		return current
	}
	if current == "" || strings.HasPrefix(incoming, current) {
		return incoming
	}
	if strings.HasPrefix(current, incoming) {
		return current
	}
	return current + incoming
}

func dial(cmd command, connID string) (*websocket.Conn, error) {
	header := http.Header{
		"X-Api-Key":         []string{cmd.APIKey},
		"X-Api-Resource-Id": []string{cmd.ResourceID},
		"X-Api-Connect-Id":  []string{connID},
	}
	addr := "wss://openspeech.bytedance.com/api/v4/ast/v2/translate"
	conn, resp, err := websocket.DefaultDialer.DialContext(context.Background(), addr, header)
	if err != nil && resp != nil {
		body, readErr := io.ReadAll(resp.Body)
		if readErr == nil {
			return nil, fmt.Errorf("%s: %s: %w", resp.Status, body, err)
		}
	}
	return conn, err
}

func send(conn *websocket.Conn, msg proto.Message) error {
	frame, err := proto.Marshal(msg)
	if err != nil {
		return fmt.Errorf("marshal protobuf: %w", err)
	}
	return conn.WriteMessage(websocket.BinaryMessage, frame)
}

func receive(conn *websocket.Conn, msg proto.Message) error {
	messageType, frame, err := conn.ReadMessage()
	if err != nil {
		return err
	}
	if messageType != websocket.BinaryMessage && messageType != websocket.TextMessage {
		return fmt.Errorf("unexpected websocket message type: %d", messageType)
	}
	return proto.Unmarshal(frame, msg)
}

func normalClose(conn *websocket.Conn) {
	_ = conn.WriteControl(
		websocket.CloseMessage,
		websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""),
		time.Now().Add(time.Second),
	)
	_ = conn.Close()
}
