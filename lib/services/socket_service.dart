import 'dart:io';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/message.dart';
import '../models/user.dart';

class SocketService {
  late io.Socket _socket;
  final String serverUrl;
  String? _currentUsername;

  void Function(User)? onUserConnected;
  void Function(String)? onUserDisconnected;
  void Function(Message)? onMessageReceived;
  void Function(List<Message>)? onChatHistoryReceived;
  void Function(List<User>)? onAllUsersReceived;
  void Function(bool success, String? error)? onRegistrationResult;
  void Function(List<dynamic>)? onUserChatsReceived;

  SocketService({required this.serverUrl});

  void connect(String username) {
    _currentUsername = username;

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket.onConnect((_) {
      print('✅ Подключено к серверу');
      _socket.emitWithAck('register', username, ack: (response) {
        if (response != null && response['success'] == true) {
          onRegistrationResult?.call(true, null);
        } else {
          onRegistrationResult?.call(false, response?['error'] ?? 'Unknown error');
        }
      });
    });

    _socket.onConnectError((err) {
      print('❌ Ошибка подключения: $err');
      onRegistrationResult?.call(false, err.toString());
    });

    _socket.on('user connected', (data) {
      onUserConnected?.call(User.fromJson(data));
    });

    _socket.on('user disconnected', (username) {
      onUserDisconnected?.call(username as String);
    });

    _socket.on('private message', (data) {
      onMessageReceived?.call(Message.fromJson(data));
    });

    _socket.on('chat history', (data) {
      final history = (data as List).map((json) => Message.fromJson(json)).toList();
      onChatHistoryReceived?.call(history);
    });

    _socket.on('all users', (data) {
      final users = (data as List).map((json) => User.fromJson(json)).toList();
      onAllUsersReceived?.call(users);
    });

    _socket.on('user chats', (data) {
      onUserChatsReceived?.call(data as List<dynamic>);
    });

    _socket.onDisconnect((_) {
      print('🔌 Отключено от сервера');
    });

    _socket.connect();
  }

  void joinRoom(String roomName) {
    _socket.emit('join room', roomName);
  }

  void sendPrivateMessage(String to, String content) {
    _socket.emit('private message', {'to': to, 'content': content});
  }

  void sendFileMessage(Map<String, dynamic> data) {
    print('📤 Отправка file message: $data');
    _socket.emit('file message', data);
  }

  void searchUsers(String query, Function(bool success, List<dynamic> users) callback) {
    _socket.emitWithAck('search users', query, ack: (response) {
      if (response != null && response['success'] == true) {
        callback(true, response['users']);
      } else {
        callback(false, []);
      }
    });
  }

  void createChat(String targetUsername, Function(bool success, String chatId) callback) {
    _socket.emitWithAck('create chat', targetUsername, ack: (response) {
      if (response != null && response['success'] == true) {
        callback(true, response['chatId']);
      } else {
        callback(false, '');
      }
    });
  }

  void getChatHistory(String chatId, Function(List<Message> messages) callback) {
    _socket.emitWithAck('get chat history', chatId, ack: (response) {
      if (response != null && response['success'] == true) {
        final history = (response['messages'] as List)
            .map((json) => Message.fromJson(json))
            .toList();
        callback(history);
      } else {
        callback([]);
      }
    });
  }

  void disconnect() {
    _socket.disconnect();
  }

  String? get currentUsername => _currentUsername;
  io.Socket get socket => _socket;
}