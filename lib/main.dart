// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';   // ← обязательно импортируйте
import 'package:provider/provider.dart';
import 'services/socket_service.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Фиксируем портретную ориентацию глобально (до запуска приложения)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const serverUrl = 'https://86ac09b7-e811-4140-a93f-0afeeac19e19.tunnel4.com'; // ваш адрес сервера
    return Provider(
      create: (_) => SocketService(serverUrl: serverUrl),
      child: MaterialApp(
        title: 'Flutter Messenger',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: const LoginScreen(),
      ),
    );
  }
}
