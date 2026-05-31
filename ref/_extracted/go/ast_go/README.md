Howto
=====

先参考protos/HOWTO.md 基于proto文件生成代码，生成的代码在protogen目录下(本代码包已生成好，需要的话也可以自行生产)

## 运行

### 调用语音同传AST
```
go run . --target=ast \
--host=wss://openspeech.bytedance.com \
--endpoint=v4/ast/v2/translate \
--resource_id=volc.service_type.10053 \
--app_key=<app_id> \
--access_key=<access_key>
```