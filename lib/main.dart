import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'app_state.dart';
import 'models.dart';
import 'widgets/message_bubble.dart';
import 'widgets/result_card.dart';
import 'widgets/image_preview_bar.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const TreasureOrTrashApp(),
    ),
  );
}

class TreasureOrTrashApp extends StatelessWidget {
  const TreasureOrTrashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Treasure or Trash',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Treasure or Trash',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  'AI Pricing Expert',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                final message = state.messages[index];
                final isUser = message.role == MessageRole.user;

                return Column(
                  crossAxisAlignment:
                      isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (message.images != null && message.images!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: message.images!.map((path) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(path),
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    if (message.content != null && message.content!.isNotEmpty)
                      MessageBubble(
                        content: message.content!,
                        role: message.role,
                      ),
                    if (message.result != null)
                      ResultCard(result: message.result!),
                    if (message.loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
          
          // Input Area
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ImagePreviewBar(
                    images: state.selectedImages,
                    onRemove: (idx) => state.removeImage(idx),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: state.isProcessing ? null : () => state.pickImages(),
                          icon: Icon(LucideIcons.image, color: Colors.grey[600]),
                          tooltip: 'Pick from Gallery',
                        ),
                        IconButton(
                          onPressed: state.isProcessing ? null : () => state.takePhoto(),
                          icon: Icon(LucideIcons.camera, color: Colors.grey[600]),
                          tooltip: 'Take Photo',
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: 'Add a message (optional)...',
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            style: const TextStyle(fontSize: 14),
                            maxLines: null,
                            enabled: !state.isProcessing,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: (state.isProcessing || state.selectedImages.isEmpty)
                              ? null
                              : () {
                                  final text = _textController.text;
                                  state.handleSubmit(text);
                                  _textController.clear();
                                  _scrollToBottom();
                                },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (state.isProcessing || state.selectedImages.isEmpty)
                                  ? Colors.grey[300]
                                  : Colors.blue[600],
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: (state.isProcessing || state.selectedImages.isEmpty)
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: const Icon(
                              LucideIcons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}