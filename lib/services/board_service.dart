import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/board.dart';
import '../models/session.dart';

class BoardService {
  final String baseUrl = AppConstants.apiBaseUrl;
  final http.Client _client;

  BoardService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Board>> getBoards(String token) async {
    final response = await _client.get(
      Uri.parse("$baseUrl/boards"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => Board.fromJson(item)).toList();
    } else {
      throw Exception("Failed to load boards: ${response.body}");
    }
  }

  Future<Board> createBoard(String title, String token) async {
    final response = await _client.post(
      Uri.parse("$baseUrl/boards"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: json.encode({"title": title}),
    );

    if (response.statusCode == 201) {
      return Board.fromJson(json.decode(response.body));
    } else {
      throw Exception("Failed to create board: ${response.body}");
    }
  }

  Future<void> deleteBoard(String boardId, String token) async {
    final response = await _client.delete(
      Uri.parse("$baseUrl/boards/$boardId"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 204) {
      throw Exception("Failed to delete board: ${response.body}");
    }
  }

  Future<PairingSession> createSession(String boardId, String token) async {
    final response = await _client.post(
      Uri.parse("$baseUrl/sessions/create"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: json.encode({"board_id": boardId}),
    );

    if (response.statusCode == 200) {
      return PairingSession.fromJson(json.decode(response.body));
    } else {
      throw Exception("Failed to create pairing session: ${response.body}");
    }
  }

  Future<PairingSession> joinSession(String sessionCode) async {
    final response = await _client.post(
      Uri.parse("$baseUrl/sessions/join"),
      headers: {
        "Content-Type": "application/json",
      },
      body: json.encode({"session_code": sessionCode}),
    );

    if (response.statusCode == 200) {
      return PairingSession.fromJson(json.decode(response.body));
    } else {
      throw Exception("Session code not found or expired: ${response.body}");
    }
  }
}

// Riverpod Provider
final boardServiceProvider = Provider<BoardService>((ref) {
  return BoardService();
});
