import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service handling image uploads to Cloudinary using unsigned upload presets.
/// Reuses the proven configuration pattern from the TeamOne reference project.
class CloudinaryService {
  static const String _cloudName = 'dt9qsvvp2';
  static const String _uploadPreset = 'AutoSpareHub';
  static const String _apiUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Standardized Cloudinary folder paths for AutoSpare
  static const String companiesFolder = 'autospare/companies';
  static const String categoriesFolder = 'autospare/categories';
  static const String productsFolder = 'autospare/products';

  /// Uploads an image file to Cloudinary under the specified [folder].
  /// Returns the secure HTTPS URL on success, or null on failure.
  Future<String?> uploadImage({
    required File imageFile,
    required String folder,
  }) async {
    try {
      if (!imageFile.existsSync()) {
        debugPrint('CloudinaryService: Error - Image file does not exist at ${imageFile.path}');
        return null;
      }

      debugPrint('CloudinaryService: Uploading ${imageFile.path} to Cloudinary folder "$folder"...');

      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl))
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = folder
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? secureUrl = data['secure_url'] as String?;
        if (secureUrl != null && secureUrl.isNotEmpty) {
          debugPrint('CloudinaryService: Image uploaded successfully -> $secureUrl');
          // Apply Cloudinary automatic quality and format optimization
          if (secureUrl.contains('/upload/')) {
            return secureUrl.replaceFirst('/upload/', '/upload/q_auto,f_auto/');
          }
          return secureUrl;
        }
      }

      debugPrint('CloudinaryService: Upload failed [HTTP ${response.statusCode}]: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('CloudinaryService: Exception occurred during upload: $e');
      return null;
    }
  }
}
