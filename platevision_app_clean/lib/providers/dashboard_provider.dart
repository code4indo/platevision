import 'package:flutter/foundation.dart';
import 'package:platevision_ai/config/app_config.dart';
import 'package:platevision_ai/models/detection_result.dart';
import 'package:platevision_ai/services/api_service.dart';
import 'package:platevision_ai/services/storage_service.dart';

// ============================================================================
// Dashboard Models
// ============================================================================

/// Represents a single activity item in the recent activity feed.
class ActivityItem {
  final String id;
  final String type; // 'analysis', 'review', 'approval', 'system', 'login'
  final String title;
  final String description;
  final DateTime timestamp;
  final String? userName;
  final Map<String, dynamic>? metadata;

  const ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.userName,
    this.metadata,
  });

  /// Returns a relative time string for display.
  String get timeAgo {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inSeconds < 60) return 'Baru saja';
    if (difference.inMinutes < 60) return '${difference.inMinutes} menit lalu';
    if (difference.inHours < 24) return '${difference.inHours} jam lalu';
    if (difference.inDays < 7) return '${difference.inDays} hari lalu';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  @override
  String toString() => 'ActivityItem($type: $title)';
}

/// Represents system status information for the dashboard.
class SystemStatus {
  final bool apiOnline;
  final bool modelLoaded;
  final String modelVersion;
  final Duration? apiResponseTime;
  final DateTime lastChecked;
  final String? errorMessage;

  const SystemStatus({
    this.apiOnline = false,
    this.modelLoaded = false,
    this.modelVersion = 'YOLOv8-v4',
    this.apiResponseTime,
    required this.lastChecked,
    this.errorMessage,
  });

  /// Returns an overall health status string.
  String get overallStatus {
    if (apiOnline && modelLoaded) return 'Operasional';
    if (apiOnline && !modelLoaded) return 'Model Tidak Tersedia';
    if (!apiOnline) return 'API Tidak Terhubung';
    return 'Tidak Diketahui';
  }

  /// Whether the system is fully operational.
  bool get isOperational => apiOnline && modelLoaded;

  /// Returns a color indicator based on status.
  /// Uses string names so the provider doesn't depend on Flutter UI directly.
  String get statusColor {
    if (isOperational) return 'green';
    if (apiOnline) return 'orange';
    return 'red';
  }

  @override
  String toString() =>
      'SystemStatus(online: $apiOnline, model: $modelLoaded, status: $overallStatus)';
}

/// Represents colony count statistics for a time period.
class ColonyStats {
  final int totalCount;
  final double averageCount;
  final int maxCount;
  final int minCount;
  final int sampleSize;
  final Map<DateTime, int> dailyCounts;

  const ColonyStats({
    this.totalCount = 0,
    this.averageCount = 0.0,
    this.maxCount = 0,
    this.minCount = 0,
    this.sampleSize = 0,
    this.dailyCounts = const {},
  });

  /// Returns the trend direction: 'up', 'down', or 'stable'.
  String get trend {
    if (dailyCounts.length < 2) return 'stable';
    final sortedDates = dailyCounts.keys.toList()..sort();
    final recent = dailyCounts[sortedDates.last] ?? 0;
    final previous = dailyCounts[sortedDates[sortedDates.length - 2]] ?? 0;
    if (recent > previous * 1.1) return 'up';
    if (recent < previous * 0.9) return 'down';
    return 'stable';
  }

  /// Returns the trend as a percentage change string.
  String get trendPercentage {
    if (dailyCounts.length < 2) return '0%';
    final sortedDates = dailyCounts.keys.toList()..sort();
    final recent = dailyCounts[sortedDates.last] ?? 0;
    final previous = dailyCounts[sortedDates[sortedDates.length - 2]] ?? 0;
    if (previous == 0) return recent > 0 ? '+100%' : '0%';
    final change = ((recent - previous) / previous * 100);
    return '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%';
  }

  @override
  String toString() =>
      'ColonyStats(total: $totalCount, avg: ${averageCount.toStringAsFixed(1)}, trend: $trend)';
}

// ============================================================================
// QC Alert Model
// ============================================================================

/// Severity type for QC alerts.
enum QcAlertType { info, warning, error }

/// Represents a quality control alert on the dashboard.
class QcAlert {
  final QcAlertType type;
  final String title;
  final String message;
  final String source;

  const QcAlert({
    required this.type,
    required this.title,
    required this.message,
    required this.source,
  });

  /// Returns the display color name for this alert type.
  String get colorName {
    switch (type) {
      case QcAlertType.error:
        return 'red';
      case QcAlertType.warning:
        return 'orange';
      case QcAlertType.info:
        return 'blue';
    }
  }

  @override
  String toString() => 'QcAlert($type: $title)';
}

// ============================================================================
// Dashboard Provider
// ============================================================================

/// Provider for managing dashboard data and statistics.
///
/// Aggregates data from backend API and local analysis history
/// to provide a comprehensive dashboard view.
class DashboardProvider extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;
  List<AnalysisResult> _analysisHistory = [];

  // --- State ---
  SystemStatus _systemStatus = SystemStatus(
    lastChecked: DateTime.now(),
  );
  List<ActivityItem> _recentActivity = [];
  bool _isLoadingStatus = false;
  final bool _isLoadingActivity = false;
  
  // --- Backend Overview Data ---
  Map<String, dynamic> _backendOverview = {};
  bool _isLoadingOverview = false;
  String? _overviewError;

  // --- QC Alerts ---
  List<QcAlert> _qcAlerts = [];

  // --- Media Type Filter ---
  String? _selectedMediaType; // null = all

  // --- Getters ---
  SystemStatus get systemStatus => _systemStatus;
  List<ActivityItem> get recentActivity =>
      List.unmodifiable(_recentActivity);
  bool get isLoadingStatus => _isLoadingStatus;
  bool get isLoadingActivity => _isLoadingActivity;
  bool get isLoadingOverview => _isLoadingOverview;
  String? get overviewError => _overviewError;
  List<QcAlert> get qcAlerts => List.unmodifiable(_qcAlerts);
  String? get selectedMediaType => _selectedMediaType;

  /// Whether the system is currently operational.
  bool get isSystemOperational => _systemStatus.isOperational;

  // --- Constructor ---

  DashboardProvider({
    required ApiService apiService,
    required StorageService storageService,
  })  : _apiService = apiService,
        _storageService = storageService {
    _analysisHistory = _storageService.loadRecentAnalyses();
    _buildActivityFeed();
  }

  // --------------------------------------------------------------------------
  // Backend Data Fetching
  // --------------------------------------------------------------------------

  /// Fetches aggregated overview stats from backend.
  Future<void> fetchBackendOverview() async {
    _isLoadingOverview = true;
    _overviewError = null;
    notifyListeners();

    try {
      _backendOverview = await _apiService.fetchAnalysisOverview();
      _buildQcAlerts();
    } catch (e) {
      _overviewError = e.toString();
      // Fall back to local data silently
    }

    _isLoadingOverview = false;
    notifyListeners();
  }

  /// Saves an analysis result to the backend server.
  Future<bool> saveAnalysisToBackend(AnalysisResult result) async {
    try {
      final classBreakdown = <String, int>{};
      for (final d in result.detections) {
        classBreakdown[d.className] =
            (classBreakdown[d.className] ?? 0) + 1;
      }

      await _apiService.saveAnalysis({
        'image_filename': result.imagePath.split('/').last,
        'image_width': result.imageWidth,
        'image_height': result.imageHeight,
        'processing_time_ms': result.processingTime.inMilliseconds,
        'model_version': result.modelVersion,
        'total_detections': result.totalDetections,
        'total_colonies': result.colonyCount,
        'avg_confidence': result.averageConfidence,
        'class_breakdown': classBreakdown,
        'detections': result.detections.map((d) => d.toJson()).toList(),
        'media_type': _selectedMediaType,
      });
      return true;
    } catch (_) {
      return false; // non-critical — data still saved locally
    }
  }

  // --------------------------------------------------------------------------
  // QC Alerts
  // --------------------------------------------------------------------------

  void _buildQcAlerts() {
    _qcAlerts.clear();

    // Alert 1: High colony count
    final totalColonies = _backendOverview['total_colonies'] as int? ?? totalColonyCount;
    if (totalColonies > AppConfig.colonyCountHigh) {
      _qcAlerts.add(QcAlert(
        type: QcAlertType.warning,
        title: 'High Colony Count',
        message: 'Total $totalColonies colonies detected exceeds threshold (${AppConfig.colonyCountHigh})',
        source: 'colony_count',
      ));
    }

    // Alert 2: High contamination (bubble + dust + crack ratio)
    final breakdown = _backendOverview['class_breakdown'] as Map<String, dynamic>? ?? {};
    final totalObjs = (breakdown.values.fold<int>(0, (s, v) => s + (v as int? ?? 0)));
    final contamination = (breakdown['bubble'] as int? ?? 0) +
        (breakdown['dust'] as int? ?? 0) +
        (breakdown['crack'] as int? ?? 0);
    if (totalObjs > 0 && (contamination / totalObjs) > 0.3) {
      _qcAlerts.add(QcAlert(
        type: QcAlertType.error,
        title: 'High Contamination Ratio',
        message: '${(contamination / totalObjs * 100).toStringAsFixed(0)}% non-colony objects detected',
        source: 'contamination',
      ));
    }

    // Alert 3: Low average confidence
    final avgConf = (_backendOverview['avg_confidence'] as num?)?.toDouble() ?? averageConfidence;
    if (avgConf > 0 && avgConf < 0.50) {
      _qcAlerts.add(QcAlert(
        type: QcAlertType.warning,
        title: 'Low Detection Confidence',
        message: 'Average confidence ${(avgConf * 100).toStringAsFixed(0)}% is below 50% threshold',
        source: 'confidence',
      ));
    }

    // Alert 4: Test count > 0 check — just info
    final totalAn = _backendOverview['total_analyses'] as int? ?? totalAnalysisCount;
    if (totalAn == 0) {
      _qcAlerts.add(QcAlert(
        type: QcAlertType.info,
        title: 'No Analysis Data',
        message: 'Run your first plate analysis to see statistics here',
        source: 'empty',
      ));
    }
  }

  /// Whether QC alerts are active (warning or error).
  bool get hasActiveAlerts =>
      _qcAlerts.any((a) => a.type == QcAlertType.warning || a.type == QcAlertType.error);

  /// Whether there are any QC alerts at all.
  bool get hasQcAlerts => _qcAlerts.isNotEmpty;

  /// Count of warning/error alerts.
  int get activeAlertCount =>
      _qcAlerts.where((a) => a.type != QcAlertType.info).length;

  // --------------------------------------------------------------------------
  // Media Type Filtering
  // --------------------------------------------------------------------------

  /// Sets the media type filter for dashboard stats.
  void setMediaTypeFilter(String? mediaType) {
    _selectedMediaType = mediaType;
    notifyListeners();
  }

  /// List of unique media types found in analysis history.
  List<String> get availableMediaTypes {
    // Extension point: when AnalysisResult gains a media_type field,
    // iterate _analysisHistory and collect unique types
    return const [];
  }

  // --------------------------------------------------------------------------
  // Processing Time Statistics
  // --------------------------------------------------------------------------

  /// Returns the fastest processing time in ms.
  double get minProcessingTimeMs {
    if (_analysisHistory.isEmpty) return 0;
    return _analysisHistory
        .map((a) => a.processingTime.inMilliseconds.toDouble())
        .reduce((a, b) => a < b ? a : b);
  }

  /// Returns the slowest processing time in ms.
  double get maxProcessingTimeMs {
    if (_analysisHistory.isEmpty) return 0;
    return _analysisHistory
        .map((a) => a.processingTime.inMilliseconds.toDouble())
        .reduce((a, b) => a > b ? a : b);
  }

  /// Total colony count from backend (cross-device).
  int get backendTotalColonies =>
      _backendOverview['total_colonies'] as int? ?? totalColonyCount;

  /// Total analyses from backend (cross-device).
  int get backendTotalAnalyses =>
      _backendOverview['total_analyses'] as int? ?? totalAnalysisCount;

  /// Average processing time from backend.
  double get backendAvgProcessingTimeMs =>
      (_backendOverview['avg_processing_time_ms'] as num?)?.toDouble() ?? 0;

  // --------------------------------------------------------------------------
  // Analysis History Updates
  // --------------------------------------------------------------------------

  /// Updates the analysis history data used for statistics.
  ///
  /// Called by the analysis provider when history changes.
  void updateAnalysisHistory(List<AnalysisResult> history) {
    _analysisHistory = List.from(history);
    _buildActivityFeed();
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Analysis Counts
  // --------------------------------------------------------------------------

  /// Total analyses today.
  int get todayAnalysisCount {
    final now = DateTime.now();
    return _analysisHistory
        .where((a) =>
            a.timestamp.year == now.year &&
            a.timestamp.month == now.month &&
            a.timestamp.day == now.day)
        .length;
  }

  /// Total analyses this week (past 7 days).
  int get weekAnalysisCount {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _analysisHistory
        .where((a) => a.timestamp.isAfter(weekAgo))
        .length;
  }

  /// Total analyses this month (past 30 days).
  int get monthAnalysisCount {
    final monthAgo = DateTime.now().subtract(const Duration(days: 30));
    return _analysisHistory
        .where((a) => a.timestamp.isAfter(monthAgo))
        .length;
  }

  /// Total analyses all time.
  int get totalAnalysisCount => _analysisHistory.length;

  // --------------------------------------------------------------------------
  // Colony Count Statistics
  // --------------------------------------------------------------------------

  /// Colony statistics for today.
  ColonyStats get todayColonyStats =>
      _calculateColonyStats(_getAnalysesForPeriod(1));

  /// Colony statistics for the past 7 days.
  ColonyStats get weekColonyStats =>
      _calculateColonyStats(_getAnalysesForPeriod(7));

  /// Colony statistics for the past 30 days.
  ColonyStats get monthColonyStats =>
      _calculateColonyStats(_getAnalysesForPeriod(30));

  /// Colony statistics for all history.
  ColonyStats get allTimeColonyStats =>
      _calculateColonyStats(_analysisHistory);

  /// Gets analyses from the past N days.
  List<AnalysisResult> _getAnalysesForPeriod(int days) {
    if (days == 1) {
      final now = DateTime.now();
      return _analysisHistory
          .where((a) =>
              a.timestamp.year == now.year &&
              a.timestamp.month == now.month &&
              a.timestamp.day == now.day)
          .toList();
    }
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _analysisHistory
        .where((a) => a.timestamp.isAfter(cutoff))
        .toList();
  }

  /// Calculates colony statistics from a list of analyses.
  ColonyStats _calculateColonyStats(List<AnalysisResult> analyses) {
    if (analyses.isEmpty) {
      return const ColonyStats();
    }

    final colonyCounts =
        analyses.map((a) => a.colonyCount).toList();

    final totalCount = colonyCounts.fold<int>(0, (sum, c) => sum + c);
    final averageCount = totalCount / colonyCounts.length;
    final maxCount = colonyCounts.reduce((a, b) => a > b ? a : b);
    final minCount = colonyCounts.reduce((a, b) => a < b ? a : b);

    // Build daily counts map
    final dailyCounts = <DateTime, int>{};
    for (final analysis in analyses) {
      final date = DateTime(
        analysis.timestamp.year,
        analysis.timestamp.month,
        analysis.timestamp.day,
      );
      dailyCounts[date] = (dailyCounts[date] ?? 0) + analysis.colonyCount;
    }

    return ColonyStats(
      totalCount: totalCount,
      averageCount: averageCount,
      maxCount: maxCount,
      minCount: minCount,
      sampleSize: analyses.length,
      dailyCounts: dailyCounts,
    );
  }

  // --------------------------------------------------------------------------
  // Detection Class Distribution
  // --------------------------------------------------------------------------

  /// Returns the distribution of detection classes across all history.
  Map<String, int> get classDistribution {
    final counts = <String, int>{};
    // Initialize with all known classes
    for (final className in AppConfig.detectionClasses) {
      counts[className] = 0;
    }
    // Count detections
    for (final analysis in _analysisHistory) {
      for (final detection in analysis.detections) {
        counts[detection.className] =
            (counts[detection.className] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Returns the distribution of detection classes for today.
  Map<String, int> get todayClassDistribution {
    final todayAnalyses = _getAnalysesForPeriod(1);
    final counts = <String, int>{};
    for (final className in AppConfig.detectionClasses) {
      counts[className] = 0;
    }
    for (final analysis in todayAnalyses) {
      for (final detection in analysis.detections) {
        counts[detection.className] =
            (counts[detection.className] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Returns class distribution as percentages.
  Map<String, double> get classDistributionPercentages {
    final distribution = classDistribution;
    final total = distribution.values.fold<int>(0, (sum, c) => sum + c);
    if (total == 0) {
      return distribution.map((k, v) => MapEntry(k, 0.0));
    }
    return distribution.map((k, v) => MapEntry(k, v / total * 100));
  }

  /// Returns total detections across all history.
  int get totalDetectionCount {
    return _analysisHistory.fold<int>(
      0,
      (sum, a) => sum + a.totalDetections,
    );
  }

  /// Returns total colony count across all history.
  int get totalColonyCount {
    return _analysisHistory.fold<int>(
      0,
      (sum, a) => sum + a.colonyCount,
    );
  }

  /// Returns total bubble count across all history.
  int get totalBubbleCount {
    return _analysisHistory.fold<int>(
      0,
      (sum, a) => sum + a.bubbleCount,
    );
  }

  /// Returns total dust count across all history.
  int get totalDustCount {
    return _analysisHistory.fold<int>(
      0,
      (sum, a) => sum + a.dustCount,
    );
  }

  /// Returns total crack count across all history.
  int get totalCrackCount {
    return _analysisHistory.fold<int>(
      0,
      (sum, a) => sum + a.crackCount,
    );
  }

  // --------------------------------------------------------------------------
  // System Status
  // --------------------------------------------------------------------------

  /// Checks the API health and updates system status.
  Future<void> checkSystemStatus() async {
    _isLoadingStatus = true;
    notifyListeners();

    try {
      final health = await _apiService.checkHealth();

      _systemStatus = SystemStatus(
        apiOnline: health.isHealthy,
        modelLoaded: health.isHealthy,
        modelVersion: health.modelVersion ?? 'YOLOv8-v4',
        apiResponseTime: health.responseTime,
        lastChecked: DateTime.now(),
      );

      // Cache the health status
      await _storageService.saveCachedHealthStatus({
        'is_healthy': health.isHealthy,
        'status': health.status,
        'model_version': health.modelVersion,
        'response_time_ms': health.responseTime?.inMilliseconds,
        'checked_at': health.checkedAt.toIso8601String(),
      });

      if (health.modelVersion != null) {
        await _storageService.saveModelVersion(health.modelVersion!);
      }
    } catch (e) {
      _systemStatus = SystemStatus(
        apiOnline: false,
        modelLoaded: false,
        lastChecked: DateTime.now(),
        errorMessage: e.toString(),
      );
    }

    _isLoadingStatus = false;
    notifyListeners();
  }

  /// Returns cached system status if available and not stale.
  SystemStatus? get cachedSystemStatus {
    if (_storageService.isCacheStale()) return null;
    final cached = _storageService.getCachedHealthStatus();
    if (cached == null) return null;

    return SystemStatus(
      apiOnline: cached['is_healthy'] as bool? ?? false,
      modelLoaded: cached['is_healthy'] as bool? ?? false,
      modelVersion: cached['model_version'] as String? ?? 'YOLOv8-v4',
      apiResponseTime: cached['response_time_ms'] != null
          ? Duration(milliseconds: cached['response_time_ms'] as int)
          : null,
      lastChecked: cached['checked_at'] != null
          ? DateTime.parse(cached['checked_at'] as String)
          : DateTime.now(),
    );
  }

  // --------------------------------------------------------------------------
  // Activity Feed
  // --------------------------------------------------------------------------

  /// Builds the recent activity feed from analysis history.
  void _buildActivityFeed() {
    _recentActivity.clear();

    // Add analysis activities from history
    for (final analysis in _analysisHistory.take(20)) {
      _recentActivity.add(ActivityItem(
        id: 'act-${analysis.id}',
        type: 'analysis',
        title: 'Analisis Selesai',
        description:
            '${analysis.colonyCount} koloni terdeteksi dari ${analysis.totalDetections} objek '
            '(${(analysis.processingTime.inMilliseconds)}ms)',
        timestamp: analysis.timestamp,
        metadata: {
          'analysis_id': analysis.id,
          'colony_count': analysis.colonyCount,
          'total_detections': analysis.totalDetections,
          'processing_time_ms': analysis.processingTime.inMilliseconds,
          'average_confidence': analysis.averageConfidence,
        },
      ));
    }

    // Sort by timestamp (newest first)
    _recentActivity.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Limit to 50 items
    if (_recentActivity.length > 50) {
      _recentActivity = _recentActivity.sublist(0, 50);
    }
  }

  /// Adds a custom activity item to the feed.
  void addActivity(ActivityItem item) {
    _recentActivity.insert(0, item);
    if (_recentActivity.length > 50) {
      _recentActivity = _recentActivity.sublist(0, 50);
    }
    notifyListeners();
  }

  /// Refreshes the dashboard data (system status + activity + backend).
  Future<void> refresh() async {
    _analysisHistory = _storageService.loadRecentAnalyses();
    _buildActivityFeed();
    await Future.wait([
      checkSystemStatus(),
      fetchBackendOverview(),
    ]);
    await _storageService.saveDashboardLastRefresh();
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Performance Metrics
  // --------------------------------------------------------------------------

  /// Returns average processing time across all history.
  Duration get averageProcessingTime {
    if (_analysisHistory.isEmpty) return Duration.zero;
    final totalMs = _analysisHistory.fold<int>(
      0,
      (sum, a) => sum + a.processingTime.inMilliseconds,
    );
    return Duration(milliseconds: totalMs ~/ _analysisHistory.length);
  }

  /// Returns average confidence across all history.
  double get averageConfidence {
    final allDetections = _analysisHistory
        .expand((a) => a.detections)
        .toList();
    if (allDetections.isEmpty) return 0.0;
    return allDetections
            .map((d) => d.confidence)
            .reduce((a, b) => a + b) /
        allDetections.length;
  }

  /// Returns high-confidence detection rate (percentage).
  double get highConfidenceRate {
    final allDetections = _analysisHistory
        .expand((a) => a.detections)
        .toList();
    if (allDetections.isEmpty) return 0.0;
    final highCount = allDetections
        .where((d) => d.confidence >= AppConfig.highConfidence)
        .length;
    return highCount / allDetections.length * 100;
  }

  /// Returns the distribution of confidence levels across all detections.
  Map<String, int> get confidenceDistribution {
    final allDetections = _analysisHistory
        .expand((a) => a.detections)
        .toList();

    int high = 0;
    int medium = 0;
    int low = 0;

    for (final detection in allDetections) {
      if (detection.confidence >= AppConfig.highConfidence) {
        high++;
      } else if (detection.confidence >= AppConfig.mediumConfidence) {
        medium++;
      } else {
        low++;
      }
    }

    return {
      'high': high,
      'medium': medium,
      'low': low,
    };
  }

  /// Returns hourly analysis counts for the current day (0-23 hours).
  Map<int, int> get todayHourlyDistribution {
    final now = DateTime.now();
    final todayAnalyses = _analysisHistory.where((a) =>
        a.timestamp.year == now.year &&
        a.timestamp.month == now.month &&
        a.timestamp.day == now.day);

    final hourly = <int, int>{};
    for (int i = 0; i < 24; i++) {
      hourly[i] = 0;
    }

    for (final analysis in todayAnalyses) {
      final hour = analysis.timestamp.hour;
      hourly[hour] = (hourly[hour] ?? 0) + 1;
    }

    return hourly;
  }

  /// Returns daily analysis counts for the past 7 days.
  Map<DateTime, int> get weeklyDailyDistribution {
    final now = DateTime.now();
    final distribution = <DateTime, int>{};

    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      distribution[date] = 0;
    }

    for (final analysis in _analysisHistory) {
      final date = DateTime(
        analysis.timestamp.year,
        analysis.timestamp.month,
        analysis.timestamp.day,
      );
      if (distribution.containsKey(date)) {
        distribution[date] = distribution[date]! + 1;
      }
    }

    return distribution;
  }

  // --------------------------------------------------------------------------
  // Summary String Helpers
  // --------------------------------------------------------------------------

  /// Returns a formatted processing time string.
  String get formattedAverageProcessingTime {
    final ms = averageProcessingTime.inMilliseconds;
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }

  /// Returns a formatted average confidence string.
  String get formattedAverageConfidence =>
      '${(averageConfidence * 100).toStringAsFixed(1)}%';

  /// Returns a formatted high-confidence rate string.
  String get formattedHighConfidenceRate =>
      '${highConfidenceRate.toStringAsFixed(1)}%';
}
