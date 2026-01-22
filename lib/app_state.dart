import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'api_service.dart';

class AppState extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  final List<PinnedResult> _pinnedResults = [];

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

  AppState() {
    _loadPinnedResults();
  }

  List<Message> get messages => _messages;
  List<XFile> get selectedImages => _selectedImages;
  bool get isProcessing => _isProcessing;
  List<PinnedResult> get pinnedResults => List.unmodifiable(_pinnedResults);

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

  bool isResultPinned(WorkflowResult result) {
    final key = _resultKey(result);
    return _pinnedResults.any((pinned) => pinned.key == key);
  }

  Future<void> pinResult(WorkflowResult result, {List<String>? imagePaths}) async {
    final key = _resultKey(result);
    if (_pinnedResults.any((pinned) => pinned.key == key)) {
      return;
    }
    final locationLabel = await _resolveLocationLabel();
    final storedImages = await _persistPinnedImages(imagePaths ?? []);
    _pinnedResults.insert(
      0,
      PinnedResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        key: key,
        result: result,
        pinnedAt: DateTime.now(),
        locationLabel: locationLabel,
        imagePaths: storedImages,
      ),
    );
    await _savePinnedResults();
    notifyListeners();
  }

  Future<void> unpinResult(PinnedResult pinned) async {
    _pinnedResults.removeWhere((entry) => entry.id == pinned.id);
    await _savePinnedResults();
    notifyListeners();
  }

  String _resultKey(WorkflowResult result) {
    final primarySource =
        result.sources.isNotEmpty ? result.sources.first.url : '';
    return [
      result.item.name,
      result.item.description,
      result.price.low,
      result.price.high,
      result.confidence.toString(),
      primarySource,
    ].join('|');
  }

  Future<File> _pinnedFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/pinned_results.json');
  }

  Future<void> _loadPinnedResults() async {
    try {
      final file = await _pinnedFile();
      if (!await file.exists()) {
        return;
      }
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _pinnedResults
          ..clear()
          ..addAll(
            decoded.whereType<Map>().map(
                  (entry) => PinnedResult.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                ),
          );
      }
    } catch (error) {
      debugPrint('Failed to load pinned results: $error');
    } finally {
      notifyListeners();
    }
  }

  Future<void> _savePinnedResults() async {
    try {
      final file = await _pinnedFile();
      final payload = _pinnedResults.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(payload));
    } catch (error) {
      debugPrint('Failed to save pinned results: $error');
    }
  }

  Future<List<String>> _persistPinnedImages(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return const [];
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/pinned_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final storedPaths = <String>[];
    for (var i = 0; i < imagePaths.length; i++) {
      final path = imagePaths[i];
      try {
        final file = File(path);
        if (!await file.exists()) {
          continue;
        }
        final extension = _safeExtension(path);
        final filename =
            'pin_${DateTime.now().millisecondsSinceEpoch}_$i$extension';
        final copy = await file.copy('${imagesDir.path}/$filename');
        storedPaths.add(copy.path);
      } catch (error) {
        debugPrint('Failed to persist pinned image: $error');
      }
    }

    return storedPaths;
  }

  String _safeExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return '.jpg';
    final ext = path.substring(dotIndex);
    if (ext.length > 6) return '.jpg';
    return ext;
  }

  Future<String?> _resolveLocationLabel() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;
      final candidates = [
        placemark.name,
        placemark.street,
        placemark.subLocality,
        placemark.locality,
        placemark.administrativeArea,
      ]
          .where((value) => value != null && value.trim().isNotEmpty)
          .map((value) => value!.trim())
          .toList();

      final picked = _pickBestPlacemarkLabel(candidates);
      if (picked != null) {
        return picked;
      }

      final locality = placemark.locality ?? '';
      final admin = placemark.administrativeArea ?? '';
      final localityLabel = [locality, admin].where((v) => v.isNotEmpty).join(', ');
      return localityLabel.isEmpty ? null : localityLabel;
    } catch (error) {
      debugPrint('Failed to resolve location label: $error');
      return null;
    }
  }

  String? _cleanPlacemarkName(String? name) {
    if (name == null) return null;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^[0-9]+$').hasMatch(trimmed)) return null;
    return trimmed;
  }

  String? _pickBestPlacemarkLabel(List<String> candidates) {
    if (candidates.isEmpty) return null;

    for (final candidate in candidates) {
      final cleaned = _cleanPlacemarkName(candidate);
      if (cleaned == null) continue;
      if (_looksLikeStreetAddress(cleaned)) {
        continue;
      }
      return cleaned;
    }

    for (final candidate in candidates) {
      final cleaned = _cleanPlacemarkName(candidate);
      if (cleaned != null) {
        return cleaned;
      }
    }

    return null;
  }

  bool _looksLikeStreetAddress(String value) {
    return RegExp(r'^\d{1,6}\s').hasMatch(value) ||
        RegExp(r'\b(Ave|Avenue|St|Street|Rd|Road|Blvd|Boulevard|Dr|Drive|Ln|Lane|Way)\b',
                caseSensitive: false)
            .hasMatch(value);
  }
}
