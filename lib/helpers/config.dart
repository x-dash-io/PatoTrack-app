import 'package:flutter_dotenv/flutter_dotenv.dart';

// AppConfig holds configuration constants for external services.
class AppConfig {
  static String get cloudinaryCloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';

  // Use an unsigned upload preset configured in Cloudinary.
  static String get cloudinaryUploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
}
