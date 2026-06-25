import pytest

@pytest.fixture
def auth_headers(client):
    # Register & Login
    client.post(
        "/api/v1/auth/register",
        json={
            "email": "teacher@example.com",
            "name": "Teacher Jane",
            "password": "testpassword123",
            "role": "teacher"
        }
    )
    response = client.post(
        "/api/v1/auth/login",
        data={
            "username": "teacher@example.com",
            "password": "testpassword123"
        }
    )
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}

@pytest.fixture
def board_id(client, auth_headers):
    response = client.post(
        "/api/v1/boards",
        json={"title": "Session Board"},
        headers=auth_headers
    )
    return response.json()["id"]

def test_create_and_join_session(client, auth_headers, board_id):
    # Create pairing session
    response = client.post(
        "/api/v1/sessions/create",
        json={"board_id": board_id},
        headers=auth_headers
    )
    assert response.status_code == 200
    data = response.json()
    assert data["board_id"] == board_id
    assert "session_code" in data
    session_code = data["session_code"]
    
    # Join pairing session
    join_response = client.post(
        "/api/v1/sessions/join",
        json={"session_code": session_code}
    )
    assert join_response.status_code == 200
    assert join_response.json()["session_code"] == session_code

def test_join_invalid_session(client):
    response = client.post(
        "/api/v1/sessions/join",
        json={"session_code": "INVALID"}
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "Active session code not found or expired"

def test_websocket_connect_valid_session(client, auth_headers, board_id):
    # Create pairing session
    response = client.post(
        "/api/v1/sessions/create",
        json={"board_id": board_id},
        headers=auth_headers
    )
    session_code = response.json()["session_code"]
    
    # Test valid WebSocket connection
    with client.websocket_connect(f"/ws/{session_code}") as websocket:
        # It accepts and we can send messages
        websocket.send_json({"event": "join_classroom", "data": {"name": "Test Client", "role": "student"}})
        data = websocket.receive_json()
        assert data["event"] in ("sync_history", "participants_list")

def test_websocket_connect_invalid_session(client):
    # Test invalid WebSocket connection closes immediately
    try:
        with client.websocket_connect("/ws/INVALIDCODE") as websocket:
            websocket.send_json({"event": "ping"})
            pytest.fail("WebSocket connection should have been rejected!")
    except Exception:
        # Connection successfully rejected / threw exception
        pass
