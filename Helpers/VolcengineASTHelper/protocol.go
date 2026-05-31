package main

type command struct {
	Type                  string `json:"type"`
	APIKey                string `json:"apiKey,omitempty"`
	ResourceID            string `json:"resourceID,omitempty"`
	Mode                  string `json:"mode,omitempty"`
	SourceLanguage        string `json:"sourceLanguage,omitempty"`
	TargetLanguage        string `json:"targetLanguage,omitempty"`
	MeetingID             string `json:"meetingID,omitempty"`
	SampleRate            int    `json:"sampleRate,omitempty"`
	Channels              int    `json:"channels,omitempty"`
	BitsPerChannel        int    `json:"bitsPerChannel,omitempty"`
	TimestampMilliseconds int    `json:"timestampMilliseconds,omitempty"`
	DataBase64            string `json:"dataBase64,omitempty"`
}

type helperEvent struct {
	Type                  string `json:"type"`
	Message               string `json:"message,omitempty"`
	Detail                string `json:"detail,omitempty"`
	SourceText            string `json:"sourceText,omitempty"`
	TranslatedText        string `json:"translatedText,omitempty"`
	StartMilliseconds     int32  `json:"startMilliseconds,omitempty"`
	EndMilliseconds       int32  `json:"endMilliseconds,omitempty"`
	SourceLanguage        string `json:"sourceLanguage,omitempty"`
	TargetLanguage        string `json:"targetLanguage,omitempty"`
	IsInterim             bool   `json:"isInterim,omitempty"`
	IsFinal               bool   `json:"isFinal,omitempty"`
	TimestampMilliseconds int    `json:"timestampMilliseconds,omitempty"`
}
