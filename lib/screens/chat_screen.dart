import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../services/socket_service.dart';
import '../services/session_service.dart';
import '../services/http_client.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../widgets/message_bubble.dart';
import 'login_screen.dart';
import 'add_contact_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, List<Message>> _messagesCache = {};
  final Map<String, Set<String>> _messageIdsCache = {};
  List<User> _users = [];
  List<dynamic> _userChats = [];
  String _currentChatPartner = 'general';
  late SocketService _socketService;
  final ImagePicker _imagePicker = ImagePicker();

  List<Message> get _currentMessages => _messagesCache[_currentChatPartner] ?? [];

  @override
  void initState() {
    super.initState();
    _socketService = Provider.of<SocketService>(context, listen: false);

    _messagesCache['general'] = [];
    _messageIdsCache['general'] = {};

    _socketService.onUserConnected = (u) {
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((user) => user.username == u.username);
        if (index != -1) _users[index] = u;
        else _users.add(u);
      });
    };

    _socketService.onUserDisconnected = (username) {
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((u) => u.username == username);
        if (index != -1) {
          _users[index] = User(username: username, status: 'Был(а) когда-то', lastSeen: DateTime.now());
        }
      });
    };

    _socketService.onMessageReceived = (msg) {
      if (!mounted) return;
      _addMessageToCache(msg);
      if (msg.receiver == _currentChatPartner || msg.sender == _currentChatPartner ||
          (_currentChatPartner == 'general' && msg.receiver == 'general')) {
        setState(() {});
        _scrollToBottom();
      }
    };

    _socketService.onChatHistoryReceived = (history) {
      if (!mounted) return;
      _cacheHistory('general', history);
      if (_currentChatPartner == 'general') {
        setState(() {});
        _scrollToBottom();
      }
    };

    _socketService.onAllUsersReceived = (users) {
      if (!mounted) return;
      setState(() => _users = users);
    };

    _socketService.onUserChatsReceived = (chats) {
      if (!mounted) return;
      setState(() => _userChats = chats);
    };
  }

  void _addMessageToCache(Message msg) {
    final chatId = msg.receiver == 'general' ? 'general' :
    (msg.sender == _socketService.currentUsername ? msg.receiver : msg.sender);
    if (!_messagesCache.containsKey(chatId)) {
      _messagesCache[chatId] = [];
      _messageIdsCache[chatId] = {};
    }
    final id = '${msg.sender}${msg.content}${msg.timestamp}';
    if (_messageIdsCache[chatId]!.contains(id)) return;
    _messageIdsCache[chatId]!.add(id);
    _messagesCache[chatId]!.add(msg);
  }

  void _cacheHistory(String chatId, List<Message> history) {
    _messagesCache[chatId] = history;
    _messageIdsCache[chatId] = {};
    for (var m in history) {
      final id = '${m.sender}${m.content}${m.timestamp}';
      _messageIdsCache[chatId]!.add(id);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _socketService.sendPrivateMessage(_currentChatPartner, text);
    _messageController.clear();
  }

  void _switchChat(String partner) {
    if (_currentChatPartner == partner) return;
    setState(() => _currentChatPartner = partner);
    _socketService.joinRoom(partner);

    if (!_messagesCache.containsKey(partner) || _messagesCache[partner]!.isEmpty) {
      _socketService.getChatHistory(partner, (messages) {
        setState(() => _cacheHistory(partner, messages));
        _scrollToBottom();
      });
    } else {
      _scrollToBottom();
    }
  }

  Future<void> _pickAndSendImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) await _uploadAndSendFile(File(image.path), 'image');
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.pickFiles();
    if (result != null) await _uploadAndSendFile(File(result.files.single.path!), 'file');
  }

  Future<void> _uploadAndSendFile(File file, String type) async {
    final uploadUrl = '${_socketService.serverUrl}/upload';
    print('📤 Загружаем файл:');
    print('   - URL: $uploadUrl');
    print('   - Путь к файлу: ${file.path}');
    print('   - Тип: $type');

    try {
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      final multipartFile = await http.MultipartFile.fromPath('file', file.path);
      request.files.add(multipartFile);
      print('   - Файл добавлен в запрос (размер: ${multipartFile.length})');

      final streamedResponse = await CustomHttpClient.send(request);
      print('   - Ответ сервера: ${streamedResponse.statusCode}');

      final response = await http.Response.fromStream(streamedResponse);
      print('   - Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ Файл успешно загружен, отправляем сообщение через сокет');
          _socketService.sendFileMessage({
            'to': _currentChatPartner,
            'content': data['fileUrl'],
            'type': type,
            'fileName': data['originalName'],
          });
        } else {
          print('❌ Ошибка в ответе сервера: ${data['error']}');
        }
      } else {
        print('❌ HTTP ошибка: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Исключение при загрузке: $e');
    }
  }


  void _logout() async {
    await SessionService().clearSession();
    _socketService.disconnect();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentChatPartner == 'general' ? 'Общий чат' : 'Чат с $_currentChatPartner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddContactScreen())),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 100,
            color: Colors.grey[100],
            child: Column(
              children: [
                ListTile(
                  title: const Text('Общий'),
                  selected: _currentChatPartner == 'general',
                  onTap: () => _switchChat('general'),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _userChats.length,
                    itemBuilder: (_, i) {
                      final chat = _userChats[i];
                      final other = chat['participants'].firstWhere(
                            (p) => p != _socketService.currentUsername,
                        orElse: () => 'Общий чат',
                      );
                      final user = _users.firstWhere(
                            (u) => u.username == other,
                        orElse: () => User(username: other, status: '', lastSeen: DateTime.now()),
                      );
                      return ListTile(
                        title: Text(user.username),
                        subtitle: Text(user.status, style: const TextStyle(fontSize: 10)),
                        selected: _currentChatPartner == user.username,
                        onTap: () => _switchChat(user.username),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _currentMessages.length,
                    itemBuilder: (_, i) {
                      final msg = _currentMessages[i];
                      return MessageBubble(
                        message: msg,
                        isMe: msg.sender == _socketService.currentUsername,
                        serverUrl: _socketService.serverUrl,
                      );
                    },
                  ),
                ),
                _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(offset: const Offset(0, -2), blurRadius: 4, color: Colors.grey[300]!)],
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.attach_file), onPressed: _pickAndSendFile),
          IconButton(icon: const Icon(Icons.image), onPressed: _pickAndSendImage),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(hintText: 'Сообщение...', border: OutlineInputBorder()),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _socketService.onUserConnected = null;
    _socketService.onUserDisconnected = null;
    _socketService.onMessageReceived = null;
    _socketService.onChatHistoryReceived = null;
    _socketService.onAllUsersReceived = null;
    _socketService.onUserChatsReceived = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}