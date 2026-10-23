import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.app import create_app
from backend.extensions import socketio

app = create_app()
test_client = socketio.test_client(app)

assert test_client.is_connected(), "Socket.IO test client failed to connect"
print("SUCCESS: Socket.IO connected successfully!")

# Test client ping
test_client.emit("ping_server", {"message": "hello socket"})
received = test_client.get_received()
assert any(msg["name"] == "pong_client" for msg in received), "Did not receive pong_client"
print("SUCCESS: Socket.IO ping/pong event verified!")

test_client.disconnect()
print("SUCCESS: All Socket.IO checks passed!")
