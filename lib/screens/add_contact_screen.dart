import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  void _search(String query) {
    if (query.isEmpty) return setState(() => _searchResults = []);
    setState(() => _isSearching = true);
    final socket = Provider.of<SocketService>(context, listen: false).socket;
    socket.emitWithAck('search users', query, ack: (response) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        if (response != null && response['success'] == true) _searchResults = response['users'];
      });
    });
  }

  void _startChat(String username) {
    final socket = Provider.of<SocketService>(context, listen: false).socket;
    socket.emitWithAck('create chat', username, ack: (response) {
      if (response != null && response['success'] == true) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${response?['error']}')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить контакт')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(hintText: 'Поиск по имени', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (_, i) {
                final user = _searchResults[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(user['username'][0])),
                  title: Text(user['username']),
                  subtitle: Text(user['status']),
                  trailing: ElevatedButton(onPressed: () => _startChat(user['username']), child: const Text('Начать чат')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}