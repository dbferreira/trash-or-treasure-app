import 'package:flutter/material.dart';
import '../models.dart';

class MessageBubble extends StatelessWidget {
  final String content;
  final MessageRole role;

  const MessageBubble({
    super.key,
    required this.content,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = role == MessageRole.user;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUser 
              ? theme.colorScheme.primaryContainer 
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          content,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isUser 
                ? theme.colorScheme.onPrimaryContainer 
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}