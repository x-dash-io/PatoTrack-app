// AppConfig holds non-secret configuration constants for external services.

class AppConfig {
  static const String cloudinaryCloudName = 'dn1qpjue4';
  // Use an unsigned upload preset configured in Cloudinary.
  // Keep this as a non-secret value; never ship API secrets in the app.
  static const String cloudinaryUploadPreset =
      'REPLACE_WITH_UNSIGNED_UPLOAD_PRESET';
}
