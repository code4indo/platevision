import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Canvas, Paint, FilterQuality, Rect;
import 'package:platevision_ai/config/app_config.dart';
import 'package:platevision_ai/models/detection_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// Storage Keys
// ============================================================================

/// Centralized storage key definitions to avoid key collisions.
class StorageKeys {
  StorageKeys._();

  // Auth
  static const String authToken = 'auth_token';
  static const String userId = 'user_id';
  static const String username = 'username';
  static const String userRole = 'user_role';

  // Analysis
  static const String recentAnalyses = 'recent_analyses';
  static const String analysisHistory = 'analysis_history';
  static const String lastAnalysisTimestamp = 'last_analysis_timestamp';

  // Preferences
  static const String confidenceThreshold = 'confidence_threshold';
  static const String iouThreshold = 'iou_threshold';
  static const String themeMode = 'theme_mode';
  static const String language = 'language';
  static const String autoSaveResults = 'auto_save_results';
  static const String showConfidenceLabels = 'show_confidence_labels';
  static const String showBoundingBoxes = 'show_bounding_boxes';
  static const String maxHistoryItems = 'max_history_items';
  static const String selectedClassFilter = 'selected_class_filter';
  static const String defaultMediaType = 'default_media_type';
  static const String defaultDilution = 'default_dilution';
  static const String defaultLabName = 'default_lab_name';

  // Cache
  static const String cacheTimestamp = 'cache_timestamp';
  static const String cachedHealthStatus = 'cached_health_status';
  static const String modelVersion = 'model_version';

  // Dashboard
  static const String dashboardLastRefresh = 'dashboard_last_refresh';
}

// ============================================================================
// User Preferences Model
// ============================================================================

/// Represents all user-configurable preferences.
class UserPreferences {
  final double confidenceThreshold;
  final double iouThreshold;
  final String themeMode; // 'system', 'light', 'dark'
  final String language; // 'id', 'en'
  final bool autoSaveResults;
  final bool showConfidenceLabels;
  final bool showBoundingBoxes;
  final int maxHistoryItems;
  final String selectedClassFilter;
  final String defaultMediaType;
  final String defaultDilution;
  final String defaultLabName;

  const UserPreferences({
    this.confidenceThreshold = AppConfig.confidenceThreshold,
    this.iouThreshold = AppConfig.iouThreshold,
    this.themeMode = 'dark',
    this.language = 'id',
    this.autoSaveResults = true,
    this.showConfidenceLabels = true,
    this.showBoundingBoxes = true,
    this.maxHistoryItems = 50,
    this.selectedClassFilter = 'all',
    this.defaultMediaType = 'PCA',
    this.defaultDilution = '10^-1',
    this.defaultLabName = '',
  });

  UserPreferences copyWith({
    double? confidenceThreshold,
    double? iouThreshold,
    String? themeMode,
    String? language,
    bool? autoSaveResults,
    bool? showConfidenceLabels,
    bool? showBoundingBoxes,
    int? maxHistoryItems,
    String? selectedClassFilter,
    String? defaultMediaType,
    String? defaultDilution,
    String? defaultLabName,
  }) {
    return UserPreferences(
      confidenceThreshold:
          confidenceThreshold ?? this.confidenceThreshold,
      iouThreshold: iouThreshold ?? this.iouThreshold,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      autoSaveResults: autoSaveResults ?? this.autoSaveResults,
      showConfidenceLabels:
          showConfidenceLabels ?? this.showConfidenceLabels,
      showBoundingBoxes: showBoundingBoxes ?? this.showBoundingBoxes,
      maxHistoryItems: maxHistoryItems ?? this.maxHistoryItems,
      selectedClassFilter:
          selectedClassFilter ?? this.selectedClassFilter,
      defaultMediaType: defaultMediaType ?? this.defaultMediaType,
      defaultDilution: defaultDilution ?? this.defaultDilution,
      defaultLabName: defaultLabName ?? this.defaultLabName,
    );
  }

  @override
  String toString() {
    return 'UserPreferences(conf: $confidenceThreshold, iou: $iouThreshold, theme: $themeMode)';
  }
}

// ============================================================================
// Storage Service
// ============================================================================

/// Service for managing local storage using SharedPreferences.
///
/// Handles persistence for:
/// - Recent analysis results (history)
/// - User preferences (thresholds, theme, display options)
/// - Authentication token
/// - Cache management
class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  /// Returns the singleton instance of StorageService.
  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  /// Initializes the storage service. Must be called before any other methods.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensures preferences are initialized before access.
  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw StateError(
        'StorageService not initialized. Call StorageService.instance.init() first.',
      );
    }
    return _prefs!;
  }

  // --------------------------------------------------------------------------
  // Auth Token Management
  // --------------------------------------------------------------------------

  /// Saves the authentication token.
  Future<bool> saveAuthToken(String token) async {
    return _preferences.setString(StorageKeys.authToken, token);
  }

  /// Retrieves the stored authentication token, or null if not set.
  String? get authToken => _preferences.getString(StorageKeys.authToken);

  /// Returns whether an auth token is currently stored.
  bool get hasAuthToken => authToken != null && authToken!.isNotEmpty;

  /// Removes the stored authentication token.
  Future<bool> removeAuthToken() async {
    return _preferences.remove(StorageKeys.authToken);
  }

  /// Saves the user ID.
  Future<bool> saveUserId(String userId) async {
    return _preferences.setString(StorageKeys.userId, userId);
  }

  /// Retrieves the stored user ID.
  String? get userId => _preferences.getString(StorageKeys.userId);

  /// Saves the username.
  Future<bool> saveUsername(String username) async {
    return _preferences.setString(StorageKeys.username, username);
  }

  /// Retrieves the stored username.
  String? get username => _preferences.getString(StorageKeys.username);

  /// Saves the user role.
  Future<bool> saveUserRole(String role) async {
    return _preferences.setString(StorageKeys.userRole, role);
  }

  /// Retrieves the stored user role.
  String? get userRole => _preferences.getString(StorageKeys.userRole);

  /// Clears all auth-related data.
  Future<void> clearAuthData() async {
    await Future.wait([
      _preferences.remove(StorageKeys.authToken),
      _preferences.remove(StorageKeys.userId),
      _preferences.remove(StorageKeys.username),
      _preferences.remove(StorageKeys.userRole),
    ]);
  }

  // --------------------------------------------------------------------------
  // Analysis History
  // --------------------------------------------------------------------------

  /// Saves a list of analysis results to recent history.
  Future<bool> saveRecentAnalyses(List<AnalysisResult> analyses) async {
    final maxItems = getMaxHistoryItems();
    final trimmed = analyses.length > maxItems
        ? analyses.sublist(0, maxItems)
        : analyses;

    final jsonList =
        trimmed.map((a) => jsonEncode(a.toJson())).toList();

    final success = await _preferences.setStringList(
      StorageKeys.recentAnalyses,
      jsonList,
    );

    if (success) {
      await _preferences.setString(
        StorageKeys.lastAnalysisTimestamp,
        DateTime.now().toIso8601String(),
      );
    }

    return success;
  }

  /// Adds a single analysis result to the history (prepends to list).
  Future<bool> addAnalysisToHistory(AnalysisResult analysis) async {
    final current = loadRecentAnalyses();
    current.insert(0, analysis);

    // Remove duplicates by ID
    final seen = <String>{};
    final unique = <AnalysisResult>[];
    for (final a in current) {
      if (!seen.contains(a.id)) {
        seen.add(a.id);
        unique.add(a);
      }
    }

    return saveRecentAnalyses(unique);
  }

  /// Loads the list of recent analysis results from storage.
  List<AnalysisResult> loadRecentAnalyses() {
    final jsonList =
        _preferences.getStringList(StorageKeys.recentAnalyses);
    if (jsonList == null || jsonList.isEmpty) return [];

    final analyses = <AnalysisResult>[];
    for (final jsonString in jsonList) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        analyses.add(AnalysisResult.fromJson(json));
      } catch (_) {
        // Skip corrupted entries
        continue;
      }
    }

    return analyses;
  }

  /// Deletes a specific analysis result from history by ID.
  Future<bool> deleteAnalysis(String analysisId) async {
    final current = loadRecentAnalyses();
    final filtered =
        current.where((a) => a.id != analysisId).toList();
    return saveRecentAnalyses(filtered);
  }

  /// Clears all analysis history.
  Future<bool> clearAnalysisHistory() async {
    await _preferences.remove(StorageKeys.lastAnalysisTimestamp);
    return _preferences.remove(StorageKeys.recentAnalyses);
  }

  /// Returns the timestamp of the last analysis, or null if never analyzed.
  DateTime? get lastAnalysisTimestamp {
    final ts = _preferences.getString(StorageKeys.lastAnalysisTimestamp);
    if (ts == null) return null;
    try {
      return DateTime.parse(ts);
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // User Preferences
  // --------------------------------------------------------------------------

  /// Saves all user preferences at once.
  Future<bool> savePreferences(UserPreferences prefs) async {
    final results = await Future.wait([
      _preferences.setDouble(
        StorageKeys.confidenceThreshold,
        prefs.confidenceThreshold,
      ),
      _preferences.setDouble(
        StorageKeys.iouThreshold,
        prefs.iouThreshold,
      ),
      _preferences.setString(StorageKeys.themeMode, prefs.themeMode),
      _preferences.setString(StorageKeys.language, prefs.language),
      _preferences.setBool(
        StorageKeys.autoSaveResults,
        prefs.autoSaveResults,
      ),
      _preferences.setBool(
        StorageKeys.showConfidenceLabels,
        prefs.showConfidenceLabels,
      ),
      _preferences.setBool(
        StorageKeys.showBoundingBoxes,
        prefs.showBoundingBoxes,
      ),
      _preferences.setInt(
        StorageKeys.maxHistoryItems,
        prefs.maxHistoryItems,
      ),
      _preferences.setString(
        StorageKeys.selectedClassFilter,
        prefs.selectedClassFilter,
      ),
      _preferences.setString(
        StorageKeys.defaultMediaType,
        prefs.defaultMediaType,
      ),
      _preferences.setString(
        StorageKeys.defaultDilution,
        prefs.defaultDilution,
      ),
      _preferences.setString(
        StorageKeys.defaultLabName,
        prefs.defaultLabName,
      ),
    ]);

    return results.every((r) => r);
  }

  /// Loads all user preferences from storage with fallback defaults.
  UserPreferences loadPreferences() {
    return UserPreferences(
      confidenceThreshold:
          _preferences.getDouble(StorageKeys.confidenceThreshold) ??
              AppConfig.confidenceThreshold,
      iouThreshold:
          _preferences.getDouble(StorageKeys.iouThreshold) ??
              AppConfig.iouThreshold,
      themeMode:
          _preferences.getString(StorageKeys.themeMode) ?? 'dark',
      language:
          _preferences.getString(StorageKeys.language) ?? 'id',
      autoSaveResults:
          _preferences.getBool(StorageKeys.autoSaveResults) ?? true,
      showConfidenceLabels:
          _preferences.getBool(StorageKeys.showConfidenceLabels) ?? true,
      showBoundingBoxes:
          _preferences.getBool(StorageKeys.showBoundingBoxes) ?? true,
      maxHistoryItems:
          _preferences.getInt(StorageKeys.maxHistoryItems) ?? 50,
      selectedClassFilter:
          _preferences.getString(StorageKeys.selectedClassFilter) ?? 'all',
      defaultMediaType:
          _preferences.getString(StorageKeys.defaultMediaType) ?? 'PCA',
      defaultDilution:
          _preferences.getString(StorageKeys.defaultDilution) ?? '10^-1',
      defaultLabName:
          _preferences.getString(StorageKeys.defaultLabName) ?? '',
    );
  }

  // --- Individual preference setters/getters for convenience ---

  /// Gets the confidence threshold preference.
  double getConfidenceThreshold() =>
      _preferences.getDouble(StorageKeys.confidenceThreshold) ??
      AppConfig.confidenceThreshold;

  /// Sets the confidence threshold preference.
  Future<bool> setConfidenceThreshold(double value) =>
      _preferences.setDouble(StorageKeys.confidenceThreshold, value);

  /// Gets the IoU threshold preference.
  double getIouThreshold() =>
      _preferences.getDouble(StorageKeys.iouThreshold) ??
      AppConfig.iouThreshold;

  /// Sets the IoU threshold preference.
  Future<bool> setIouThreshold(double value) =>
      _preferences.setDouble(StorageKeys.iouThreshold, value);

  /// Gets the theme mode preference.
  String getThemeMode() =>
      _preferences.getString(StorageKeys.themeMode) ?? 'dark';

  /// Sets the theme mode preference.
  Future<bool> setThemeMode(String mode) =>
      _preferences.setString(StorageKeys.themeMode, mode);

  /// Gets the selected class filter.
  String getSelectedClassFilter() =>
      _preferences.getString(StorageKeys.selectedClassFilter) ?? 'all';

  /// Sets the selected class filter.
  Future<bool> setSelectedClassFilter(String filter) =>
      _preferences.setString(StorageKeys.selectedClassFilter, filter);

  /// Gets max history items count.
  int getMaxHistoryItems() =>
      _preferences.getInt(StorageKeys.maxHistoryItems) ?? 50;

  /// Sets max history items count.
  Future<bool> setMaxHistoryItems(int count) =>
      _preferences.setInt(StorageKeys.maxHistoryItems, count);

  /// Gets whether auto-save is enabled.
  bool getAutoSaveResults() =>
      _preferences.getBool(StorageKeys.autoSaveResults) ?? true;

  /// Sets auto-save preference.
  Future<bool> setAutoSaveResults(bool value) =>
      _preferences.setBool(StorageKeys.autoSaveResults, value);

  /// Gets whether confidence labels should be shown.
  bool getShowConfidenceLabels() =>
      _preferences.getBool(StorageKeys.showConfidenceLabels) ?? true;

  /// Sets show confidence labels preference.
  Future<bool> setShowConfidenceLabels(bool value) =>
      _preferences.setBool(StorageKeys.showConfidenceLabels, value);

  /// Gets whether bounding boxes should be shown.
  bool getShowBoundingBoxes() =>
      _preferences.getBool(StorageKeys.showBoundingBoxes) ?? true;

  /// Sets show bounding boxes preference.
  Future<bool> setShowBoundingBoxes(bool value) =>
      _preferences.setBool(StorageKeys.showBoundingBoxes, value);

  // --------------------------------------------------------------------------
  // Cache Management
  // --------------------------------------------------------------------------

  /// Saves the cached health status as JSON.
  Future<bool> saveCachedHealthStatus(Map<String, dynamic> status) async {
    await _preferences.setString(
      StorageKeys.cachedHealthStatus,
      jsonEncode(status),
    );
    await _preferences.setString(
      StorageKeys.cacheTimestamp,
      DateTime.now().toIso8601String(),
    );
    return true;
  }

  /// Loads the cached health status.
  Map<String, dynamic>? getCachedHealthStatus() {
    final json = _preferences.getString(StorageKeys.cachedHealthStatus);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Gets the timestamp when the cache was last updated.
  DateTime? getCacheTimestamp() {
    final ts = _preferences.getString(StorageKeys.cacheTimestamp);
    if (ts == null) return null;
    try {
      return DateTime.parse(ts);
    } catch (_) {
      return null;
    }
  }

  /// Returns whether the cache is stale (older than [maxAge]).
  bool isCacheStale({Duration maxAge = const Duration(minutes: 5)}) {
    final timestamp = getCacheTimestamp();
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > maxAge;
  }

  /// Saves the model version string.
  Future<bool> saveModelVersion(String version) =>
      _preferences.setString(StorageKeys.modelVersion, version);

  /// Gets the cached model version.
  String? get modelVersion =>
      _preferences.getString(StorageKeys.modelVersion);

  /// Saves the dashboard last refresh timestamp.
  Future<bool> saveDashboardLastRefresh() =>
      _preferences.setString(
        StorageKeys.dashboardLastRefresh,
        DateTime.now().toIso8601String(),
      );

  /// Gets the dashboard last refresh timestamp.
  DateTime? get dashboardLastRefresh {
    final ts =
        _preferences.getString(StorageKeys.dashboardLastRefresh);
    if (ts == null) return null;
    try {
      return DateTime.parse(ts);
    } catch (_) {
      return null;
    }
  }


  // --------------------------------------------------------------------------
  // Analysis Image Storage
  // --------------------------------------------------------------------------

  /// Maximum base64 size to store per image (4MB ≈ 3MB raw JPEG)
  static const int _maxImageBase64Size = 4 * 1024 * 1024;

  /// Maximum dimension for stored thumbnail (keeps storage size manageable)
  static const int _thumbnailMaxDimension = 800;

  /// Compresses image bytes to a smaller thumbnail for storage.
  /// Resizes to max [_thumbnailMaxDimension] pixels on the longest side,
  /// encodes as PNG using dart:ui (works on all platforms including Web).
  /// Returns the compressed bytes, or null if compression fails.
  static Future<Uint8List?> compressForStorage(List<int> imageBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        Uint8List.fromList(imageBytes),
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final maxDim = _thumbnailMaxDimension;
      double scale = 1.0;
      if (image.width > maxDim || image.height > maxDim) {
        scale = maxDim / (image.width > image.height ? image.width : image.height);
      }

      final newWidth = (image.width * scale).round();
      final newHeight = (image.height * scale).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final resizedImage = await picture.toImage(newWidth, newHeight);
      final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      // Compression failed — return original as fallback
      try {
        return Uint8List.fromList(imageBytes);
      } catch (_) {
        return null;
      }
    }
  }

  /// Saves the image bytes for a specific analysis result.
  /// Images are automatically compressed to a thumbnail before storage
  /// to ensure they fit within SharedPreferences/localStorage size limits.
  Future<bool> saveAnalysisImage(String analysisId, List<int> imageBytes) async {
    try {
      // Step 1: Compress the image for storage
      final compressed = await compressForStorage(imageBytes);
      if (compressed == null) return false;

      // Step 2: Encode to base64
      final base64Str = base64Encode(compressed);

      // Step 3: Check size limit
      if (base64Str.length > _maxImageBase64Size) {
        // Still too large after compression — try smaller thumbnail
        try {
          final tinyCodec = await ui.instantiateImageCodec(Uint8List.fromList(imageBytes));
          final tinyFrame = await tinyCodec.getNextFrame();
          final tinyImage = tinyFrame.image;

          const tinyMax = 400;
          double tinyScale = tinyMax / (tinyImage.width > tinyImage.height ? tinyImage.width : tinyImage.height);
          final tw = (tinyImage.width * tinyScale).round();
          final th = (tinyImage.height * tinyScale).round();

          final tinyRecorder = ui.PictureRecorder();
          final tinyCanvas = Canvas(tinyRecorder);
          tinyCanvas.drawImageRect(
            tinyImage,
            Rect.fromLTWH(0, 0, tinyImage.width.toDouble(), tinyImage.height.toDouble()),
            Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
            Paint()..filterQuality = FilterQuality.medium,
          );

          final tinyPicture = tinyRecorder.endRecording();
          final tinyResized = await tinyPicture.toImage(tw, th);
          final tinyByteData = await tinyResized.toByteData(format: ui.ImageByteFormat.png);
          if (tinyByteData == null) return false;

          final tinyBase64 = base64Encode(tinyByteData.buffer.asUint8List());
          if (tinyBase64.length > _maxImageBase64Size) return false;
          return _preferences.setString('analysis_image_$analysisId', tinyBase64);
        } catch (_) {
          return false;
        }
      }

      return _preferences.setString('analysis_image_$analysisId', base64Str);
    } catch (_) {
      return false;
    }
  }

  /// Loads the image bytes for a specific analysis result.
  /// Returns null if no image is stored for the given analysis ID.
  Uint8List? loadAnalysisImage(String analysisId) {
    try {
      final base64Str = _preferences.getString('analysis_image_$analysisId');
      if (base64Str == null) return null;
      return Uint8List.fromList(base64Decode(base64Str));
    } catch (_) {
      return null;
    }
  }

  /// Deletes the image bytes for a specific analysis result.
  Future<bool> deleteAnalysisImage(String analysisId) async {
    return _preferences.remove('analysis_image_$analysisId');
  }

  /// Cleans up analysis images that are no longer in the history list.
  /// Call this after trimming history to remove orphaned images.
  Future<void> cleanupOldImages(List<String> keepAnalysisIds) async {
    final keys = _preferences.getKeys();
    final imageKeys = keys.where((k) => k.startsWith('analysis_image_'));
    final keepSet = keepAnalysisIds.toSet();

    for (final key in imageKeys) {
      final id = key.replaceFirst('analysis_image_', '');
      if (!keepSet.contains(id)) {
        await _preferences.remove(key);
      }
    }
  }

  /// Deletes all analysis images from storage.
  Future<void> deleteAllAnalysisImages() async {
    final keys = _preferences.getKeys();
    final imageKeys = keys.where((k) => k.startsWith('analysis_image_'));

    for (final key in imageKeys) {
      await _preferences.remove(key);
    }
  }

  // --------------------------------------------------------------------------
  // Cache Cleanup
  // --------------------------------------------------------------------------

  /// Clears all cached data (keeps auth and preferences).
  Future<void> clearCache() async {
    await Future.wait([
      _preferences.remove(StorageKeys.cachedHealthStatus),
      _preferences.remove(StorageKeys.cacheTimestamp),
      _preferences.remove(StorageKeys.modelVersion),
      _preferences.remove(StorageKeys.dashboardLastRefresh),
    ]);
  }

  /// Clears all stored data (full reset).
  Future<bool> clearAll() async {
    return _preferences.clear();
  }

  /// Returns the total number of stored keys (for debugging/metrics).
  int get storedKeysCount => _preferences.getKeys().length;

  /// Returns all stored keys (for debugging).
  Set<String> get storedKeys => _preferences.getKeys();
}
