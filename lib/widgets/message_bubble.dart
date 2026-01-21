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
    final isUser = role == MessageRole.user;
    
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        gradient: isUser 
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
            )
          : null,
        color: isUser ? null : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(22),
          topRight: const Radius.circular(22),
          bottomLeft: Radius.circular(isUser ? 22 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 22),
        ),
        boxShadow: [
          BoxShadow(
            color: isUser 
              ? const Color(0xFF6366F1).withOpacity(0.2)
              : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: !isUser ? Border.all(color: const Color(0xFFF1F5F9)) : null,
      ),
      child: Text(
        content,
        style: TextStyle(
          color: isUser ? Colors.white : const Color(0xFF334155),
          fontSize: 15,
          fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
          height: 1.4,
        ),
      ),
    );
  }
}
