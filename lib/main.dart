import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'models.dart';
import 'widgets/message_bubble.dart';
import 'widgets/result_card.dart';
import 'widgets/image_preview_bar.dart';
import 'screens/saved_results_view.dart';
import 'screens/live_scan_view.dart';
import 'package:share_plus/share_plus.dart';

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
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Trash or Treasure', 'Live Scan', 'Pinned Results'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        centerTitle: false,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const ChatView(),
          LiveScanView(isActive: _currentIndex == 1),
          const SavedResultsView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.center_focus_strong),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.push_pin_outlined),
            label: 'Pinned',
          ),
        ],
      ),
    );
  }
}

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
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

    return Column(
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
                    if (isUser &&
                        message.images != null &&
                        message.images!.isNotEmpty)
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
                      ResultCard(
                        result: message.result!,
                        actions: [
                          _buildShareAction(
                            message.result!,
                            message.images ??
                                _findImagesForResult(state.messages, index),
                          ),
                          _buildPinAction(
                            context,
                            state,
                            message.result!,
                            message.images ??
                                _findImagesForResult(state.messages, index),
                          ),
                        ],
                      ),
                      if (message.loading)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: state.isProcessing
                                    ? () => state.cancelProcessing()
                                    : null,
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
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

  Widget _buildPinAction(
    BuildContext context,
    AppState state,
    WorkflowResult result,
    List<String> imagePaths,
  ) {
    final isPinned = state.isResultPinned(result);

    return FilledButton.tonalIcon(
      onPressed: () async {
        if (isPinned) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Already pinned')),
          );
          return;
        }
        try {
          await state.pinResult(result, imagePaths: imagePaths);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pinned to your list')),
          );
        } catch (error) {
          debugPrint('Failed to pin result: $error');
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pin failed. Try again.')),
          );
        }
      },
      icon: Icon(isPinned ? Icons.check : Icons.push_pin),
      label: Text(isPinned ? 'Pinned' : 'Pin'),
    );
  }

  Widget _buildShareAction(
    WorkflowResult result,
    List<String> imagePaths,
  ) {
    return IconButton(
      tooltip: 'Share',
      icon: const Icon(Icons.share_outlined),
      onPressed: () => _shareResult(result, imagePaths),
    );
  }

  Future<void> _shareResult(
    WorkflowResult result,
    List<String> imagePaths,
  ) async {
    final text = _formatShareText(result);
    if (imagePaths.isNotEmpty) {
      final files = imagePaths.map((path) => XFile(path)).toList();
      await Share.shareXFiles(files, text: text);
    } else {
      await Share.share(text);
    }
  }

  String _formatShareText(WorkflowResult result) {
    final low = _formatPrice(result.price.low);
    final high = _formatPrice(result.price.high);
    return [
      result.item.name,
      result.item.description,
      'Estimated value: $low — $high',
    ].where((line) => line.trim().isNotEmpty).join('\n\n');
  }

  String _formatPrice(String price) {
    if (price.isEmpty) return r'$0';
    if (price.startsWith(r'$')) return price;
    return r'$' + price;
  }

  List<String> _findImagesForResult(List<Message> messages, int resultIndex) {
    for (var i = resultIndex - 1; i >= 0; i--) {
      final message = messages[i];
      if (message.role == MessageRole.user &&
          message.images != null &&
          message.images!.isNotEmpty) {
        return message.images!;
      }
    }
    return const [];
  }
}
