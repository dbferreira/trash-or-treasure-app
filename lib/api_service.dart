import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'models.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    // For Android Emulator, 10.0.2.2 points to the host's localhost
    baseUrl: 'http://10.0.2.2:4111',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  Future<WorkflowResult> processImages({
    required List<File> images,
    String? description,
  }) async {
    final List<Map<String, String>> formattedImages = [];

    for (var image in images) {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = _getMimeType(image.path);
      formattedImages.add({
        'url': 'data:$mimeType;base64,$base64Image',
        'mimeType': mimeType,
      });
    }

    try {
      final response = await _dio.post(
        '/api/workflows/pricingWorkflow/start-async',
        data: {
          'inputData': {
            'images': formattedImages,
            if (description != null && description.isNotEmpty)
              'description': description,
          },
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        
        // Match the extraction logic from Vue app
        final resultData = data['steps']?['identify-and-price']?['output'] ?? 
                          data['result'] ??
                          data['results'] ?? 
                          data['output'];
        
        if (resultData == null) {
          throw Exception('No result data found in response');
        }

        return WorkflowResult.fromJson(resultData);
      } else {
        throw Exception('Failed to process images: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  String _getMimeType(String path) {
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
