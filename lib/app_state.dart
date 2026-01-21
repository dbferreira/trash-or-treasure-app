import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'api_service.dart';

class AppState extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  final List<Message> _messages = [
    Message(
      id: '1',
      role: MessageRole.assistant,
      content: 'Hi! I can help you identify items and estimate their resale value. Take a photo of an item to get started!',
      timestamp: DateTime.now(),
    ),
  ];

  final List<XFile> _selectedImages = [];
  bool _isProcessing = false;

  List<Message> get messages => _messages;
  List<XFile> get selectedImages => _selectedImages;
  bool get isProcessing => _isProcessing;

  void addImage(XFile image) {
    _selectedImages.add(image);
    notifyListeners();
  }

  void removeImage(int index) {
    _selectedImages.removeAt(index);
    notifyListeners();
  }

  Future<void> pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 75,
    );
    if (images.isNotEmpty) {
      _selectedImages.addAll(images);
      notifyListeners();
    }
  }

  Future<void> takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 75,
    );
    if (photo != null) {
      _selectedImages.add(photo);
      notifyListeners();
    }
  }

  Future<void> handleSubmit(String? description) async {
    if (_isProcessing || _selectedImages.isEmpty) return;

    final userMsgId = DateTime.now().millisecondsSinceEpoch.toString();
    final currentImages = List<XFile>.from(_selectedImages);
    final currentText = description;

    // Add user message
    _messages.add(Message(
      id: userMsgId,
      role: MessageRole.user,
      content: currentText,
      images: currentImages.map((e) => e.path).toList(),
      timestamp: DateTime.now(),
    ));

    // Reset inputs
    _selectedImages.clear();
    _isProcessing = true;
    notifyListeners();

    // Add loading assistant message
    final assistantMsgId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
    _messages.add(Message(
      id: assistantMsgId,
      role: MessageRole.assistant,
      loading: true,
      timestamp: DateTime.now(),
    ));
    notifyListeners();

    try {
      final result = await _apiService.processImages(
        images: currentImages.map((e) => File(e.path)).toList(),
        description: currentText,
      );

      // Update assistant message with result
      final msgIdx = _messages.indexWhere((m) => m.id == assistantMsgId);
      if (msgIdx != -1) {
        _messages[msgIdx] = Message(
          id: assistantMsgId,
          role: MessageRole.assistant,
          result: result,
          timestamp: DateTime.now(),
          loading: false,
        );
      }
    } catch (error) {
      debugPrint('Workflow error: $error');
      final msgIdx = _messages.indexWhere((m) => m.id == assistantMsgId);
      if (msgIdx != -1) {
        _messages[msgIdx] = Message(
          id: assistantMsgId,
          role: MessageRole.assistant,
          content: 'Sorry, I encountered an error while processing those images. Please try again.',
          timestamp: DateTime.now(),
          loading: false,
        );
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
