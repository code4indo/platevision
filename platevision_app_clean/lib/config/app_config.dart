class AppConfig {
  static const String appName = 'PlateVisionAI';
  static const String appVersion = '1.0.0';
  static const String apiBaseUrl = 'https://healthcare.jatnikonm.tech';
  static const String apiPredictEndpoint = '/api/predict';
  static const String apiHealthEndpoint = '/api/health';
  static const double minImageResolution = 300; // DPI
  static const double confidenceThreshold = 0.25;
  static const double iouThreshold = 0.45;
  static const int maxImageSizeMB = 20;
  static const Duration apiTimeout = Duration(seconds: 30);
  static const List<String> supportedFormats = [
    'jpg',
    'jpeg',
    'png',
    'bmp',
    'tiff',
  ];

  // Model classes
  static const List<String> detectionClasses = ['colony', 'bubble', 'dust', 'crack'];
  static const Map<String, String> classLabels = {
    'colony': 'Koloni',
    'bubble': 'Gelembung',
    'dust': 'Debu',
    'crack': 'Retakan',
  };

  // V4 Model metrics
  static const double map50 = 0.9145;
  static const double map5095 = 0.6984;
  static const double precision = 0.9235;
  static const double recall = 0.8731;

  // Detection class colors mapping (for reference; actual Color objects in AppColors)
  static const Map<String, String> classColorHex = {
    'colony': '#00E676',
    'bubble': '#42A5F5',
    'dust': '#FFB74D',
    'crack': '#EF5350',
  };

  // API request headers
  static const Map<String, String> apiHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'multipart/form-data',
  };

  // Confidence display thresholds
  static const double highConfidence = 0.80;
  static const double mediumConfidence = 0.50;
  static const double lowConfidence = 0.25;

  // Colony count severity levels (CFU/mL)
  static const int colonyCountLow = 30;
  static const int colonyCountMedium = 100;
  static const int colonyCountHigh = 300;

  /// Get confidence level string based on value
  static String getConfidenceLevel(double confidence) {
    if (confidence >= highConfidence) return 'High';
    if (confidence >= mediumConfidence) return 'Medium';
    return 'Low';
  }

  /// Get colony count severity based on count
  static String getColonySeverity(int count) {
    if (count <= colonyCountLow) return 'Low';
    if (count <= colonyCountMedium) return 'Moderate';
    if (count <= colonyCountHigh) return 'High';
    return 'Very High';
  }

  /// Format detection class name for display
  static String formatClassName(String className) {
    return classLabels[className] ?? className.toUpperCase();
  }

  /// Check if file extension is supported
  static bool isSupportedFormat(String extension) {
    return supportedFormats.contains(extension.toLowerCase());
  }

  /// Get full API URL for prediction
  static String get predictUrl => '$apiBaseUrl$apiPredictEndpoint';

  /// Get full API URL for health check
  static String get healthUrl => '$apiBaseUrl$apiHealthEndpoint';
}
