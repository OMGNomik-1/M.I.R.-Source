import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import '../models/message.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final String serverUrl;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.serverUrl,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.message.type == 'video') {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.type == 'video' && oldWidget.message.content != widget.message.content) {
      _initializeVideo();
    }
  }

  void _initializeVideo() {
    final videoUrl = _getFullUrl(widget.message.content);
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isVideoInitialized = true);
        }
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  String _getFullUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${widget.serverUrl}$path';
  }

  void _openImageViewer(BuildContext context) {
    final imageUrl = _getFullUrl(widget.message.content);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => _downloadFile(imageUrl, widget.message.fileName ?? 'image.jpg'),
              ),
            ],
          ),
          body: Container(
            color: Colors.black,
            child: PhotoView(
              imageProvider: NetworkImage(imageUrl),
              minScale: PhotoViewComputedScale.contained * 0.8,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
        ),
      ),
    );
  }

  void _openVideoViewer(BuildContext context) {
    final videoUrl = _getFullUrl(widget.message.content);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => _downloadFile(videoUrl, widget.message.fileName ?? 'video.mp4'),
              ),
            ],
          ),
          body: Center(
            child: _isVideoInitialized
                ? AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            )
                : const CircularProgressIndicator(),
          ),
          floatingActionButton: _isVideoInitialized
              ? FloatingActionButton(
            onPressed: () {
              setState(() {
                _videoController!.value.isPlaying
                    ? _videoController!.pause()
                    : _videoController!.play();
              });
            },
            child: Icon(
              _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
          )
              : null,
        ),
      ),
    );
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Скачивание файла...'), duration: Duration(seconds: 2)),
      );

      // 1. Скачиваем во временную папку
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$fileName';
      final dio = Dio();
      await dio.download(url, tempPath);

      // 2. Читаем скачанный файл в Uint8List
      final file = File(tempPath);
      final Uint8List bytes = await file.readAsBytes();

      // 3. Вызываем системный диалог сохранения (SAF)
      final String? outputPath = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
      );

      // 4. Удаляем временный файл
      await file.delete();

      if (outputPath == null) return; // пользователь отменил

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл успешно сохранён')),
      );

      // 5. Предлагаем открыть файл
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Готово'),
          content: const Text('Файл сохранён. Открыть его?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Закрыть'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Открыть'),
            ),
          ],
        ),
      );

      if (shouldOpen == true) {
        await OpenFile.open(outputPath);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при загрузке: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final isMedia = widget.message.type == 'image' || widget.message.type == 'video' || widget.message.type == 'file';

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: EdgeInsets.all(isMedia ? 4 : 12),
        decoration: BoxDecoration(
          color: widget.isMe ? Colors.lightBlue[100] : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
            bottomRight: Radius.circular(widget.isMe ? 4 : 16),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isMe)
              Text(
                widget.message.sender,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            const SizedBox(height: 4),
            if (widget.message.type == 'image')
              GestureDetector(
                onTap: () => _openImageViewer(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: _getFullUrl(widget.message.content),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, size: 40),
                    ),
                  ),
                ),
              )
            else if (widget.message.type == 'video')
              GestureDetector(
                onTap: () => _openVideoViewer(context),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isVideoInitialized
                      ? Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: VideoPlayer(_videoController!),
                      ),
                      const Icon(Icons.play_circle_fill, size: 50, color: Colors.white),
                    ],
                  )
                      : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              )
            else if (widget.message.type == 'file')
                GestureDetector(
                  onTap: () => _downloadFile(_getFullUrl(widget.message.content), widget.message.fileName ?? 'file'),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, size: 40),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.message.fileName ?? 'Файл',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Нажмите, чтобы скачать',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(widget.message.content),
            const SizedBox(height: 4),
            Text(
              timeFormat.format(widget.message.timestamp),
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}