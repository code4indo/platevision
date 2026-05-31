import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:platevision_ai/config/app_config.dart';
import 'package:platevision_ai/models/detection_result.dart';
import 'package:platevision_ai/services/api_service.dart';
import 'package:platevision_ai/services/storage_service.dart';

// ============================================================================
// Analysis State Enum
// ============================================================================

/// Represents the current state of an analysis operation.
enum AnalysisState {
  idle,
  loading,
  success,
  error,
}

// ============================================================================
// Analysis Provider
// ============================================================================

/// Provider for managing analysis state, history, and filtering.
///
/// Handles the complete lifecycle of plate image analysis:
/// - Running predictions via the API service
/// - Maintaining analysis history with local persistence
/// - Filtering detections by class and confidence threshold
/// - Error handling and state transitions
class AnalysisProvider extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;

  // --- State ---
  AnalysisState _state = AnalysisState.idle;
  AnalysisResult? _currentResult;
  Uint8List? _currentImageBytes;
  List<AnalysisResult> _history = [];
  String _selectedClassFilter = 'all';
  double _confidenceThreshold = AppConfig.confidenceThreshold;
  double _iouThreshold = AppConfig.iouThreshold;
  String? _errorMessage;
  String? _currentImagePath;

  // --- Getters ---
  AnalysisState get state => _state;
  AnalysisResult? get currentResult => _currentResult;
  Uint8List? get currentImageBytes => _currentImageBytes;
  List<AnalysisResult> get history => List.unmodifiable(_history);
  String get selectedClassFilter => _selectedClassFilter;
  double get confidenceThreshold => _confidenceThreshold;
  double get iouThreshold => _iouThreshold;
  String? get errorMessage => _errorMessage;
  String? get currentImagePath => _currentImagePath;

  /// Whether an analysis is currently in progress.
  bool get isAnalyzing => _state == AnalysisState.loading;

  /// Whether there is a current result to display.
  bool get hasResult => _currentResult != null;

  /// Whether there is an error to display.
  bool get hasError => _state == AnalysisState.error && _errorMessage != null;

  /// Returns filtered detections from the current result.
  List<DetectionResult> get filteredDetections {
    if (_currentResult == null) return [];

    var detections = _currentResult!.detections;

    // Filter by confidence threshold
    detections = detections
        .where((d) => d.confidence >= _confidenceThreshold)
        .toList();

    // Filter by class
    if (_selectedClassFilter != 'all') {
      detections = detections
          .where((d) => d.className == _selectedClassFilter)
          .toList();
    }

    return detections;
  }

  /// Returns filtered colony count.
  int get filteredColonyCount =>
      filteredDetections.where((d) => d.className == 'colony').length;

  /// Returns filtered detection counts by class.
  Map<String, int> get filteredClassCounts {
    final counts = <String, int>{};
    for (final detection in filteredDetections) {
      counts[detection.className] = (counts[detection.className] ?? 0) + 1;
    }
    return counts;
  }

  /// Returns total number of history items.
  int get historyCount => _history.length;

  /// Returns analyses from today.
  List<AnalysisResult> get todayAnalyses {
    final now = DateTime.now();
    return _history
        .where((a) =>
            a.timestamp.year == now.year &&
            a.timestamp.month == now.month &&
            a.timestamp.day == now.day)
        .toList();
  }

  /// Returns analyses from the past 7 days.
  List<AnalysisResult> get weekAnalyses {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _history.where((a) => a.timestamp.isAfter(weekAgo)).toList();
  }

  /// Returns analyses from the past 30 days.
  List<AnalysisResult> get monthAnalyses {
    final monthAgo = DateTime.now().subtract(const Duration(days: 30));
    return _history.where((a) => a.timestamp.isAfter(monthAgo)).toList();
  }

  /// Total colony count across all history.
  int get totalHistoricalColonyCount =>
      _history.fold<int>(0, (sum, a) => sum + a.colonyCount);

  /// Average colony count across all history.
  double get averageHistoricalColonyCount {
    if (_history.isEmpty) return 0.0;
    return totalHistoricalColonyCount / _history.length;
  }

  // --- Constructor ---

  AnalysisProvider({
    required ApiService apiService,
    required StorageService storageService,
  })  : _apiService = apiService,
        _storageService = storageService {
    _loadFromStorage();
  }

  // --------------------------------------------------------------------------
  // Storage Loading
  // --------------------------------------------------------------------------

  /// Loads saved preferences and history from local storage.
  Future<void> _loadFromStorage() async {
    try {
      final prefs = _storageService.loadPreferences();
      _confidenceThreshold = prefs.confidenceThreshold;
      _iouThreshold = prefs.iouThreshold;
      _selectedClassFilter = prefs.selectedClassFilter;
      _history = _storageService.loadRecentAnalyses();
      notifyListeners();
    } catch (_) {
      // Use defaults if storage loading fails
    }
  }

  // --------------------------------------------------------------------------
  // Analysis Operations
  // --------------------------------------------------------------------------

  /// Runs analysis on an image at the given path.
  ///
  /// Transitions state: idle -> loading -> success/error
  /// On success, saves the result to history.
  Future<void> runAnalysis(String imagePath) async {
    if (_state == AnalysisState.loading) return; // Prevent double-submit

    _currentImagePath = imagePath;
    _state = AnalysisState.loading;
    _errorMessage = null;
    _currentResult = null;
    notifyListeners();

    try {
      final prediction = await _apiService.predictImage(
        imagePath: imagePath,
        confidenceThreshold: _confidenceThreshold,
        iouThreshold: _iouThreshold,
      );

      final result = AnalysisResult(
        id: ApiService.generateId(),
        imagePath: imagePath,
        timestamp: DateTime.now(),
        processingTime: prediction.processingTime,
        detections: prediction.detections,
        imageWidth: prediction.imageWidth,
        imageHeight: prediction.imageHeight,
        modelVersion: prediction.modelVersion,
      );

      _currentResult = result;
      _state = AnalysisState.success;

      // Auto-save to history
      final prefs = _storageService.loadPreferences();
      if (prefs.autoSaveResults) {
        await addToHistory(result);
      }

      // Sync to backend (non-blocking)
      _syncToBackend(result);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _state = AnalysisState.error;
    } catch (e) {
      _errorMessage = 'Kesalahan tak terduga: ${e.toString()}';
      _state = AnalysisState.error;
    }

    notifyListeners();
  }

  /// Runs analysis on raw image bytes.
  Future<void> runAnalysisFromBytes({
    required List<int> imageBytes,
    required String fileName,
    String sampleId = '',
    Map<String, String>? metadata,
  }) async {
    if (_state == AnalysisState.loading) return;

    // Store image bytes for display on analysis result page
    _currentImageBytes = Uint8List.fromList(imageBytes);
    _currentImagePath = null;
    _state = AnalysisState.loading;
    _errorMessage = null;
    _currentResult = null;
    notifyListeners();

    try {
      final prediction = await _apiService.predictImageBytes(
        imageBytes: imageBytes,
        fileName: fileName,
        confidenceThreshold: _confidenceThreshold,
        iouThreshold: _iouThreshold,
      );

      final result = AnalysisResult(
        id: ApiService.generateId(),
        sampleId: sampleId,
        imagePath: fileName,
        timestamp: DateTime.now(),
        processingTime: prediction.processingTime,
        detections: prediction.detections,
        imageWidth: prediction.imageWidth,
        imageHeight: prediction.imageHeight,
        modelVersion: prediction.modelVersion,
        mediaType: metadata?['media_type'] ?? '',
        dilution: metadata?['dilution'] ?? '',
        inoculationMethod: metadata?['inoculation_method'] ?? '',
        inoculumVolume: metadata?['inoculum_volume'] ?? '',
        sampleType: metadata?['sample_type'] ?? '',
        plateReplicate: metadata?['plate_replicate'] ?? '',
        samplingTime: metadata?['sampling_time'] ?? '',
        samplingLocation: metadata?['sampling_location'] ?? '',
        samplingOfficer: metadata?['sampling_officer'] ?? '',
        incubatorEntryTime: metadata?['incubator_entry_time'] ?? '',
        incubatorTemp: metadata?['incubator_temp'] ?? '',
        incubationTime: metadata?['incubation_time'] ?? '',
        incubationCondition: metadata?['incubation_condition'] ?? '',
        incubatorId: metadata?['incubator_id'] ?? '',
        diluent: metadata?['diluent'] ?? '',
        mediaLot: metadata?['media_lot'] ?? '',
        analystName: metadata?['analyst_name'] ?? '',
        morphologyNotes: metadata?['morphology_notes'] ?? '',
      );

      _currentResult = result;
      _state = AnalysisState.success;

      final prefs = _storageService.loadPreferences();
      if (prefs.autoSaveResults) {
        await addToHistory(result);
      }

      // Sync to backend (non-blocking)
      _syncToBackend(result);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _state = AnalysisState.error;
    } catch (e) {
      _errorMessage = 'Kesalahan tak terduga: ${e.toString()}';
      _state = AnalysisState.error;
    }

    notifyListeners();
  }

  /// Syncs an analysis result to the backend server (non-blocking).
  Future<void> _syncToBackend(AnalysisResult result) async {
    try {
      final classBreakdown = <String, int>{};
      for (final d in result.detections) {
        classBreakdown[d.className] =
            (classBreakdown[d.className] ?? 0) + 1;
      }

      await _apiService.saveAnalysis({
        'sample_id': result.sampleId,
        'image_filename': result.imagePath.split('/').last,
        'image_width': result.imageWidth,
        'image_height': result.imageHeight,
        'processing_time_ms': result.processingTime.inMilliseconds,
        'inference_time_ms': result.processingTime.inMilliseconds,
        'model_version': result.modelVersion,
        'total_detections': result.totalDetections,
        'total_colonies': result.colonyCount,
        'avg_confidence': result.averageConfidence,
        'class_breakdown': classBreakdown,
        'detections': result.detections.map((d) => d.toJson()).toList(),
      });
    } catch (_) {
      // Non-critical — data still saved locally
    }
  }

  /// Clears the current analysis result and resets to idle state.
  void clearResult() {
    _currentResult = null;
    _currentImageBytes = null;
    _currentImagePath = null;
    _errorMessage = null;
    _state = AnalysisState.idle;
    notifyListeners();
  }

  /// Retries the last failed analysis.
  Future<void> retryAnalysis() async {
    if (_currentImagePath != null) {
      await runAnalysis(_currentImagePath!);
    }
  }

  // --------------------------------------------------------------------------
  // History Management
  // --------------------------------------------------------------------------

  /// Adds an analysis result to the history and persists it.
  Future<void> addToHistory(AnalysisResult result) async {
    // Remove duplicate if exists
    _history.removeWhere((a) => a.id == result.id);

    // Prepend to history
    _history.insert(0, result);

    // Trim to max history size
    final maxItems = _storageService.getMaxHistoryItems();
    if (_history.length > maxItems) {
      _history = _history.sublist(0, maxItems);
    }

    // Persist to storage
    await _storageService.saveRecentAnalyses(_history);

    // Save image bytes for this analysis (if available)
    if (_currentImageBytes != null && result.id.isNotEmpty) {
      await _storageService.saveAnalysisImage(result.id, _currentImageBytes!);
    }

    // Clean up orphaned images
    final keepIds = _history.map((a) => a.id).toList();
    await _storageService.cleanupOldImages(keepIds);

    notifyListeners();
  }

  /// Deletes a specific analysis from history by ID.
  Future<void> deleteAnalysis(String analysisId) async {
    _history.removeWhere((a) => a.id == analysisId);
    await _storageService.deleteAnalysis(analysisId);
    await _storageService.deleteAnalysisImage(analysisId);

    // If the deleted analysis is the current result, clear it
    if (_currentResult?.id == analysisId) {
      _currentResult = null;
      _state = AnalysisState.idle;
    }

    notifyListeners();
  }

  /// Clears all analysis history.
  Future<void> clearHistory() async {
    _history.clear();
    await _storageService.clearAnalysisHistory();
    await _storageService.deleteAllAnalysisImages();
    notifyListeners();
  }

  /// Loads a specific analysis from history as the current result.
  /// Also loads the associated image bytes from storage.
  void loadFromHistory(AnalysisResult result) {
    _currentResult = result;
    _currentImageBytes = _storageService.loadAnalysisImage(result.id);
    _state = AnalysisState.success;
    _errorMessage = null;
    notifyListeners();
  }

  /// Updates the manual adjustment counts (added/removed colonies).
  Future<void> updateManualAdjustments({
    required String id,
    required int added,
    required int removed,
  }) async {
    // Update in history
    final index = _history.indexWhere((a) => a.id == id);
    if (index != -1) {
      _history[index] = _history[index].copyWith(
        added: added,
        removed: removed,
      );
      await _storageService.saveRecentAnalyses(_history);
    }

    // Update current result
    if (_currentResult?.id == id) {
      _currentResult = _currentResult!.copyWith(
        added: added,
        removed: removed,
      );
    }

    notifyListeners();
  }

  /// Updates the metadata for a specific analysis result.
  Future<void> updateAnalysisMetadata(String id, Map<String, String> metadata) async {
    final index = _history.indexWhere((a) => a.id == id);
    if (index == -1) return;

    final updated = _history[index].copyWith(
      sampleId: metadata['sample_id'],
      sampleType: metadata['sample_type'],
      mediaType: metadata['media_type'],
      dilution: metadata['dilution'],
      inoculationMethod: metadata['inoculation_method'],
      inoculumVolume: metadata['inoculum_volume'],
      plateReplicate: metadata['plate_replicate'],
      samplingTime: metadata['sampling_time'],
      samplingLocation: metadata['sampling_location'],
      samplingOfficer: metadata['sampling_officer'],
      incubatorEntryTime: metadata['incubator_entry_time'],
      incubatorTemp: metadata['incubator_temp'],
      incubationTime: metadata['incubation_time'],
      incubationCondition: metadata['incubation_condition'],
      incubatorId: metadata['incubator_id'],
      diluent: metadata['diluent'],
      mediaLot: metadata['media_lot'],
      analystName: metadata['analyst_name'],
      morphologyNotes: metadata['morphology_notes'],
    );

    _history[index] = updated;
    await _storageService.saveRecentAnalyses(_history);

    if (_currentResult?.id == id) {
      _currentResult = updated;
    }

    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Filtering
  // --------------------------------------------------------------------------

  /// Sets the detection class filter.
  ///
  /// Use 'all' to show all classes, or a specific class name like 'colony'.
  void filterByClass(String className) {
    _selectedClassFilter = className;
    _storageService.setSelectedClassFilter(className);
    notifyListeners();
  }

  /// Resets the class filter to show all detections.
  void clearClassFilter() {
    filterByClass('all');
  }

  // --------------------------------------------------------------------------
  // Threshold Management
  // --------------------------------------------------------------------------

  /// Updates the confidence threshold and re-filters current results.
  Future<void> setConfidenceThreshold(double threshold) async {
    _confidenceThreshold = threshold;
    await _storageService.setConfidenceThreshold(threshold);
    notifyListeners();
  }

  /// Updates the IoU threshold for future analyses.
  Future<void> setIouThreshold(double threshold) async {
    _iouThreshold = threshold;
    await _storageService.setIouThreshold(threshold);
    notifyListeners();
  }

  /// Resets thresholds to default values.
  Future<void> resetThresholds() async {
    _confidenceThreshold = AppConfig.confidenceThreshold;
    _iouThreshold = AppConfig.iouThreshold;
    await _storageService.setConfidenceThreshold(_confidenceThreshold);
    await _storageService.setIouThreshold(_iouThreshold);
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Statistics Helpers
  // --------------------------------------------------------------------------

  /// Returns the count of each detection class across all history.
  Map<String, int> get historicalClassCounts {
    final counts = <String, int>{};
    for (final analysis in _history) {
      for (final detection in analysis.detections) {
        counts[detection.className] =
            (counts[detection.className] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Returns daily colony counts for the past N days.
  Map<DateTime, int> getColonyCountsByDay({int days = 7}) {
    final counts = <DateTime, int>{};
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      counts[date] = 0;
    }

    for (final analysis in _history) {
      final date = DateTime(
        analysis.timestamp.year,
        analysis.timestamp.month,
        analysis.timestamp.day,
      );
      if (counts.containsKey(date)) {
        counts[date] = counts[date]! + analysis.colonyCount;
      }
    }

    return counts;
  }

  /// Returns average confidence across all history.
  double get historicalAverageConfidence {
    if (_history.isEmpty) return 0.0;
    final allDetections = _history
        .expand((a) => a.detections)
        .toList();
    if (allDetections.isEmpty) return 0.0;
    return allDetections
            .map((d) => d.confidence)
            .reduce((a, b) => a + b) /
        allDetections.length;
  }

  // --------------------------------------------------------------------------
  // Override
  // --------------------------------------------------------------------------
}
