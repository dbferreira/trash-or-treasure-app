import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  static const mainColor = Color.fromARGB(255, 23, 140, 186);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trash or Treasure',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: mainColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: mainColor,
          brightness: Brightness.dark,
        ),
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
        title: const Text('Trash or Treasure'),
        centerTitle: false,
        actions: [],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                final message = state.messages[index];
                final isUser = message.role == MessageRole.user;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment:
                        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (message.images != null && message.images!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: message.images!.map((path) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(path),
                                  width: 150,
                                  height: 150,
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
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          _buildInputArea(state),
        ],
      ),
    );
  }

  Widget _buildInputArea(AppState state) {
    final theme = Theme.of(context);
    
    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.selectedImages.isNotEmpty)
              ImagePreviewBar(
                images: state.selectedImages,
                onRemove: (idx) => state.removeImage(idx),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: state.isProcessing ? null : () => state.pickImages(),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  IconButton(
                    onPressed: state.isProcessing ? null : () => state.takePhoto(),
                    icon: const Icon(Icons.camera_alt_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Describe the item...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        isDense: true,
                      ),
                      maxLines: 3,
                      minLines: 1,
                      enabled: !state.isProcessing,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    onPressed: (state.isProcessing || state.selectedImages.isEmpty)
                        ? null
                        : () {
                            final text = _textController.text;
                            state.handleSubmit(text);
                            _textController.clear();
                            _scrollToBottom();
                          },
                    elevation: 0,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
