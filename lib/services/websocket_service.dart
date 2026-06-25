import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final String sessionCode;
  
  // Callbacks for UI updates
  final Function(List<dynamic> history)? onSyncHistory;
  final Function(Map<String, dynamic> stroke)? onStrokeReceived;
  final Function(Map<String, dynamic> shape)? onShapeReceived;
  final Function(String action)? onActionReceived;
  final Function(bool isConnected)? onConnectionChanged;
  final Function(List<dynamic> users)? onParticipantsReceived;

  WebSocketService({
    required this.sessionCode,
    this.onSyncHistory,
    this.onStrokeReceived,
    this.onShapeReceived,
    this.onActionReceived,
    this.onConnectionChanged,
    this.onParticipantsReceived,
  });

  bool get isConnected => _isConnected;

  void connect() {
    if (_isConnected) return;
    
    final uri = Uri.parse(AppConstants.wsUrl(sessionCode));
    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      onConnectionChanged?.call(true);

      _channel!.stream.listen(
        (message) {
          _handleIncomingMessage(message);
        },
        onError: (err) {
          debugPrint("WebSocket Error: $err");
          _handleDisconnect();
        },
        onDone: () {
          debugPrint("WebSocket Connection Closed");
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint("WebSocket Connection Failed: $e");
      _handleDisconnect();
    }
  }

  void _handleIncomingMessage(dynamic rawMessage) {
    try {
      final Map<String, dynamic> data = json.decode(rawMessage);
      final String event = data['event'] ?? '';
      
      switch (event) {
        case 'sync_history':
          final history = data['data'] as List<dynamic>? ?? [];
          onSyncHistory?.call(history);
          break;
        case 'draw_stroke':
          if (data['data'] != null) {
            onStrokeReceived?.call(data['data']);
          }
          break;
        case 'draw_shape':
          if (data['data'] != null) {
            onShapeReceived?.call(data['data']);
          }
          break;
        case 'canvas_action':
          final action = data['data']?['action'] ?? '';
          onActionReceived?.call(action);
          break;
        case 'participants_list':
          final users = data['data'] as List<dynamic>? ?? [];
          onParticipantsReceived?.call(users);
          break;
      }
    } catch (e) {
      debugPrint("Failed to parse websocket message: $e");
    }
  }

  void sendStroke(Map<String, dynamic> strokeData) {
    if (!_isConnected || _channel == null) return;
    
    final packet = {
      'event': 'draw_stroke',
      'session_code': sessionCode,
      'data': strokeData,
    };
    _channel!.sink.add(json.encode(packet));
  }

  void sendShape(Map<String, dynamic> shapeData) {
    if (!_isConnected || _channel == null) return;

    final packet = {
      'event': 'draw_shape',
      'session_code': sessionCode,
      'data': shapeData,
    };
    _channel!.sink.add(json.encode(packet));
  }

  void sendAction(String action) {
    if (!_isConnected || _channel == null) return;

    final packet = {
      'event': 'canvas_action',
      'session_code': sessionCode,
      'data': {'action': action},
    };
    _channel!.sink.add(json.encode(packet));
  }

  void joinClassroom(String name, String role) {
    if (!_isConnected || _channel == null) return;

    final packet = {
      'event': 'join_classroom',
      'session_code': sessionCode,
      'data': {
        'name': name,
        'role': role
      },
    };
    _channel!.sink.add(json.encode(packet));
  }

  void _handleDisconnect() {
    _isConnected = false;
    onConnectionChanged?.call(false);
    _channel = null;
    
    // Auto Reconnect Logic
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isConnected) {
        debugPrint("Attempting WebSocket Reconnect for $sessionCode...");
        connect();
      }
    });
  }

  void disconnect() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
  }
}
