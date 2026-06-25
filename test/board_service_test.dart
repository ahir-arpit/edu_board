import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:edu_board/services/board_service.dart';

void main() {
  group('BoardService Unit Tests', () {
    test('getBoards fetches successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, endsWith('/boards'));
        expect(request.headers['Authorization'], 'Bearer fake-token');
        
        final mockResponse = [
          {
            "id": "board-123",
            "title": "Math Board",
            "owner_id": "owner-1",
            "created_at": "2026-06-25T12:00:00Z"
          }
        ];
        return http.Response(json.encode(mockResponse), 200);
      });

      final service = BoardService(client: mockClient);
      final boards = await service.getBoards('fake-token');

      expect(boards.length, 1);
      expect(boards[0].id, 'board-123');
      expect(boards[0].title, 'Math Board');
    });

    test('createBoard submits successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, endsWith('/boards'));
        expect(request.method, 'POST');
        final body = json.decode(request.body);
        expect(body['title'], 'New Physics Board');

        final mockResponse = {
          "id": "board-999",
          "title": "New Physics Board",
          "owner_id": "owner-1",
          "created_at": "2026-06-25T12:05:00Z"
        };
        return http.Response(json.encode(mockResponse), 201);
      });

      final service = BoardService(client: mockClient);
      final board = await service.createBoard('New Physics Board', 'fake-token');

      expect(board.id, 'board-999');
      expect(board.title, 'New Physics Board');
    });

    test('createSession establishes session successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, endsWith('/sessions/create'));
        expect(request.method, 'POST');
        final body = json.decode(request.body);
        expect(body['board_id'], 'board-123');

        final mockResponse = {
          "id": "sess-abc",
          "session_code": "XYZ123",
          "board_id": "board-123",
          "is_active": true,
          "created_at": "2026-06-25T12:10:00Z"
        };
        return http.Response(json.encode(mockResponse), 200);
      });

      final service = BoardService(client: mockClient);
      final session = await service.createSession('board-123', 'fake-token');

      expect(session.id, 'sess-abc');
      expect(session.sessionCode, 'XYZ123');
      expect(session.boardId, 'board-123');
    });
  });
}
