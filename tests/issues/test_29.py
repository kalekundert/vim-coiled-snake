#!/usr/bin/env python3

payload = (
    """\
{
"ProtocolVersion": 1,
"WebSocketPort": {%s}
}"""
        % servers.websocket_server.port
)
self.send_response(200)



