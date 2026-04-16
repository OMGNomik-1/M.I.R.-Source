import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';
import '../services/session_service.dart';
import 'chat_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final SessionService _sessionService = SessionService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final saved = await _sessionService.getSavedUsername();
    if (saved != null && saved.isNotEmpty) {
      _connect(saved);
    }
  }

  void _connect(String username) {
    final socketService = Provider.of<SocketService>(context, listen: false);
    setState(() => _isLoading = true);
    socketService.onRegistrationResult = (success, error) {
      setState(() => _isLoading = false);
      if (success) {
        _sessionService.saveUserSession(username);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
      } else {
        _sessionService.clearSession();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $error')));
      }
    };
    socketService.connect(username);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Добро пожаловать!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Имя пользователя', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: () => _usernameController.text.trim().isNotEmpty
                  ? _connect(_usernameController.text.trim())
                  : null,
              child: const Text('Войти'),
            ),
          ],
        ),
      ),
    );
  }
}