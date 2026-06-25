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

def test_create_board(client, auth_headers):
    response = client.post(
        "/api/v1/boards",
        json={"title": "Algebra 101"},
        headers=auth_headers
    )
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "Algebra 101"
    assert "id" in data

def test_get_boards(client, auth_headers):
    # Create boards
    client.post(
        "/api/v1/boards",
        json={"title": "Board A"},
        headers=auth_headers
    )
    client.post(
        "/api/v1/boards",
        json={"title": "Board B"},
        headers=auth_headers
    )
    
    response = client.get("/api/v1/boards", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0]["title"] == "Board A"
    assert data[1]["title"] == "Board B"

def test_get_board_by_id(client, auth_headers):
    create_response = client.post(
        "/api/v1/boards",
        json={"title": "Single Board"},
        headers=auth_headers
    )
    board_id = create_response.json()["id"]
    
    response = client.get(f"/api/v1/boards/{board_id}", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["title"] == "Single Board"

def test_delete_board(client, auth_headers):
    create_response = client.post(
        "/api/v1/boards",
        json={"title": "To Delete"},
        headers=auth_headers
    )
    board_id = create_response.json()["id"]
    
    delete_response = client.delete(f"/api/v1/boards/{board_id}", headers=auth_headers)
    assert delete_response.status_code == 204
    
    # Verify it is deleted
    get_response = client.get(f"/api/v1/boards/{board_id}", headers=auth_headers)
    assert get_response.status_code == 404
