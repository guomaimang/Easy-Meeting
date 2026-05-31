module easy-meeting/volcengine-ast-helper

go 1.20

require (
	code.byted.org/data-speech/wsclientsdk v0.0.0
	github.com/google/uuid v1.6.0
	github.com/gorilla/websocket v1.5.3
	google.golang.org/protobuf v1.34.2
)

require (
	golang.org/x/net v0.27.0 // indirect
	golang.org/x/sys v0.30.0 // indirect
	golang.org/x/text v0.22.0 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20240730163845-b1a4ccb954bf // indirect
	google.golang.org/grpc v1.64.1 // indirect
)

replace code.byted.org/data-speech/wsclientsdk => ../../ref/_extracted/go/ast_go
