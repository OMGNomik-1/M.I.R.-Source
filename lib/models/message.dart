class Message {
  final String sender;
  final String receiver;
  final String content;
  final DateTime timestamp;
  final String type;   // 'text', 'image', 'file'
  final String? fileName;

  Message({
    required this.sender,
    required this.receiver,
    required this.content,
    required this.timestamp,
    this.type = 'text',
    this.fileName,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      sender: json['sender'] ?? '',
      receiver: json['receiver'] ?? '',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      type: json['type'] ?? 'text',
      fileName: json['fileName'],
    );
  }

  bool get isMedia => type == 'image' || type == 'file';
}