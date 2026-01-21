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
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? Colors.blue[600] : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 20),
        ),
        boxShadow: [
          if (!isUser)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
        ],
        border: !isUser ? Border.all(color: Colors.grey[200]!) : null,
      ),
      child: Text(
        content,
        style: TextStyle(
          color: isUser ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      ),
    );
  }
}
