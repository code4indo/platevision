import 'dart:math' as math;
import 'dart:ui';

import 'package:platevision_ai/config/app_config.dart';
import 'package:platevision_ai/theme/app_colors.dart';

/// Represents a single YOLO detection result with bounding box, class, and confidence.
class DetectionResult {
  final String className;
  final double confidence;
  final Rect boundingBox;
  final int classId;

  DetectionResult({
    required this.className,
    required this.confidence,
    required this.boundingBox,
    required this.classId,
  });

  /// Creates a DetectionResult from the YOLO JSON output format.
  ///
  /// Expected JSON formats:
  /// 1. Array format: [x1, y1, x2, y2, confidence, classId]
  /// 2. Object format: {"bbox": [x1, y1, x2, y2], "confidence": 0.95, "class": 0, "class_name": "colony"}
  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    Rect box;
    String name;
    double conf;
    int cId;

    if (json.containsKey('bbox')) {
      // Object format with explicit bbox array
      final List<dynamic> bbox = json['bbox'] as List<dynamic>;
      box = Rect.fromLTRB(
        (bbox[0] as num).toDouble(),
        (bbox[1] as num).toDouble(),
        (bbox[2] as num).toDouble(),
        (bbox[3] as num).toDouble(),
      );
      conf = (json['confidence'] as num).toDouble();
      cId = (json['class'] as num).toInt();
      name = json['class_name'] as String? ??
          _resolveClassName(cId);
    } else if (json.containsKey('box')) {
      // Alternate object format with "box" key
      final boxData = json['box'];
      if (boxData is List) {
        box = Rect.fromLTRB(
          (boxData[0] as num).toDouble(),
          (boxData[1] as num).toDouble(),
          (boxData[2] as num).toDouble(),
          (boxData[3] as num).toDouble(),
        );
      } else if (boxData is Map) {
        // {"x1":..., "y1":..., "x2":..., "y2":...} or {"xmin":..., "ymin":..., "xmax":..., "ymax":...}
        final x1 = (boxData['x1'] ?? boxData['xmin'] ?? 0) as num;
        final y1 = (boxData['y1'] ?? boxData['ymin'] ?? 0) as num;
        final x2 = (boxData['x2'] ?? boxData['xmax'] ?? 0) as num;
        final y2 = (boxData['y2'] ?? boxData['ymax'] ?? 0) as num;
        box = Rect.fromLTRB(x1.toDouble(), y1.toDouble(), x2.toDouble(), y2.toDouble());
      } else {
        box = Rect.zero;
      }
      conf = ((json['confidence'] ?? json['score'] ?? 0.0) as num).toDouble();
      cId = ((json['class'] ?? json['class_id'] ?? json['category_id'] ?? 0) as num).toInt();
      name = json['class_name'] ?? json['name'] ?? json['label'] ?? _resolveClassName(cId);
    } else if (json.containsKey('xyxy')) {
      // Format with explicit xyxy key
      final List<dynamic> xyxy = json['xyxy'] as List<dynamic>;
      box = Rect.fromLTRB(
        (xyxy[0] as num).toDouble(),
        (xyxy[1] as num).toDouble(),
        (xyxy[2] as num).toDouble(),
        (xyxy[3] as num).toDouble(),
      );
      conf = (json['confidence'] as num).toDouble();
      cId = (json['class'] as num).toInt();
      name = json['class_name'] as String? ?? _resolveClassName(cId);
    } else {
      // Fallback: try to interpret the whole map as raw detection
      box = Rect.zero;
      conf = ((json['confidence'] ?? json['score'] ?? 0.0) as num).toDouble();
      cId = ((json['class'] ?? json['class_id'] ?? 0) as num).toInt();
      name = json['class_name'] ?? json['name'] ?? json['label'] ?? _resolveClassName(cId);
    }

    return DetectionResult(
      className: name,
      confidence: conf,
      boundingBox: box,
      classId: cId,
    );
  }

  /// Creates a DetectionResult from a raw YOLO array output.
  ///
  /// YOLO raw format: [x1, y1, x2, y2, confidence, classId]
  factory DetectionResult.fromYoloList(List<dynamic> list) {
    return DetectionResult(
      className: _resolveClassName(list.length > 5 ? (list[5] as num).toInt() : 0),
      confidence: (list[4] as num).toDouble(),
      boundingBox: Rect.fromLTRB(
        (list[0] as num).toDouble(),
        (list[1] as num).toDouble(),
        (list[2] as num).toDouble(),
        (list[3] as num).toDouble(),
      ),
      classId: list.length > 5 ? (list[5] as num).toInt() : 0,
    );
  }

  /// Resolves a class ID to its string name based on AppConfig.
  static String _resolveClassName(int classId) {
    if (classId >= 0 && classId < AppConfig.detectionClasses.length) {
      return AppConfig.detectionClasses[classId];
    }
    return 'unknown_$classId';
  }

  /// Returns the display color for this detection class.
  Color get classColor {
    return AppColors.getDetectionColor(className);
  }

  /// Returns the Indonesian label for this detection class.
  String get classLabel {
    return AppConfig.classLabels[className] ?? className.toUpperCase();
  }

  /// Returns formatted confidence percentage string.
  String get confidenceLabel => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Returns the confidence level: high, medium, or low.
  String get confidenceLevel {
    if (confidence >= AppConfig.highConfidence) return 'high';
    if (confidence >= AppConfig.mediumConfidence) return 'medium';
    return 'low';
  }

  /// Returns the width of the bounding box.
  double get boxWidth => boundingBox.width;

  /// Returns the height of the bounding box.
  double get boxHeight => boundingBox.height;

  /// Returns the area of the bounding box in pixels.
  double get boxArea => boundingBox.width * boundingBox.height;

  /// Returns the center point of the bounding box.
  Offset get center => boundingBox.center;

  /// Checks if this detection overlaps with another detection.
  bool overlaps(DetectionResult other, {double iouThreshold = 0.5}) {
    final intersection = boundingBox.intersect(other.boundingBox);
    if (intersection.isEmpty) return false;
    final intersectionArea = intersection.width * intersection.height;
    final unionArea = boxArea + other.boxArea - intersectionArea;
    if (unionArea <= 0) return false;
    return intersectionArea / unionArea > iouThreshold;
  }

  /// Converts to JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'class_name': className,
      'confidence': confidence,
      'class': classId,
      'bbox': [
        boundingBox.left,
        boundingBox.top,
        boundingBox.right,
        boundingBox.bottom,
      ],
    };
  }

  /// Creates a copy with optional parameter overrides.
  DetectionResult copyWith({
    String? className,
    double? confidence,
    Rect? boundingBox,
    int? classId,
  }) {
    return DetectionResult(
      className: className ?? this.className,
      confidence: confidence ?? this.confidence,
      boundingBox: boundingBox ?? this.boundingBox,
      classId: classId ?? this.classId,
    );
  }

  @override
  String toString() {
    return 'DetectionResult(className: $className, confidence: $confidenceLabel, bbox: $boundingBox)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DetectionResult &&
        other.className == className &&
        other.confidence == confidence &&
        other.boundingBox == boundingBox &&
        other.classId == classId;
  }

  @override
  int get hashCode {
    return Object.hash(className, confidence, boundingBox, classId);
  }
}

/// Represents a complete analysis result for a single plate image.
class AnalysisResult {
  final String id;
  final String sampleId;
  final String imagePath;
  final DateTime timestamp;
  final Duration processingTime;
  final List<DetectionResult> detections;
  final int imageWidth;
  final int imageHeight;
  final String modelVersion;

  // ── Metadata fields ──
  final String mediaType;
  final String dilution;
  final String inoculationMethod;
  final String inoculumVolume;
  final String sampleType;
  final String plateReplicate;
  final String samplingTime;
  final String samplingLocation;
  final String samplingOfficer;
  final String incubatorEntryTime;
  final String incubatorTemp;
  final String incubationTime;
  final String incubationCondition;
  final String incubatorId;
  final String diluent;
  final String mediaLot;
  final String analystName;
  final String morphologyNotes;

  // ── ISO 17025 §5.3 Environmental Conditions ──
  final String ambientTemperature;
  final String ambientHumidity;
  final String laboratory;

  // ── Manual adjustment fields ──
  final int added;
  final int removed;

  AnalysisResult({
    required this.id,
    this.sampleId = '',
    required this.imagePath,
    required this.timestamp,
    required this.processingTime,
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
    this.modelVersion = 'YOLOv8-v4',
    this.mediaType = '',
    this.dilution = '',
    this.inoculationMethod = '',
    this.inoculumVolume = '',
    this.sampleType = '',
    this.plateReplicate = '',
    this.samplingTime = '',
    this.samplingLocation = '',
    this.samplingOfficer = '',
    this.incubatorEntryTime = '',
    this.incubatorTemp = '',
    this.incubationTime = '',
    this.incubationCondition = '',
    this.incubatorId = '',
    this.diluent = '',
    this.mediaLot = '',
    this.analystName = '',
    this.morphologyNotes = '',
    this.ambientTemperature = '',
    this.ambientHumidity = '',
    this.laboratory = '',
    this.added = 0,
    this.removed = 0,
  });

  /// Total number of detections.
  int get totalDetections => detections.length;

  /// Count of colony detections.
  int get colonyCount =>
      detections.where((d) => d.className == 'colony').length;

  /// Net count after manual user adjustments (added − removed).
  int get adjustedCount => colonyCount + added - removed;

  /// Returns the CFU/mL based on dilution and colony count.
  /// Assumes standard 100µL spread plate method if inoculumVolume is not provided.
  double get cfuPerML {
    if (colonyCount == 0) return 0;
    
    double dilutionFactor;
    try {
      final dilutionStr = dilution.trim();
      if (dilutionStr.isEmpty) {
        dilutionFactor = 1.0;
      } else if (dilutionStr.startsWith('10^-')) {
        final exponent = int.parse(dilutionStr.substring(4));
        dilutionFactor = 1 / math.pow(10, exponent);
      } else if (dilutionStr.startsWith('1:')) {
        final divisor = int.parse(dilutionStr.substring(2));
        dilutionFactor = 1 / divisor;
      } else {
        dilutionFactor = double.parse(dilutionStr);
      }
    } catch (_) {
      dilutionFactor = 1.0;
    }

    double volumeInML = 0.1; // Default 100µL
    try {
      final volStr = inoculumVolume.toLowerCase().trim();
      if (volStr.isNotEmpty) {
        if (volStr.contains('ml')) {
          volumeInML = double.parse(volStr.replaceAll(RegExp(r'[^0-9.]'), ''));
        } else if (volStr.contains('ul') || volStr.contains('µl')) {
          volumeInML = double.parse(volStr.replaceAll(RegExp(r'[^0-9.]'), '')) / 1000;
        } else {
          volumeInML = double.parse(volStr.replaceAll(RegExp(r'[^0-9.]'), ''));
        }
      }
    } catch (_) {}

    if (volumeInML <= 0) volumeInML = 0.1;

    return colonyCount / (dilutionFactor * volumeInML);
  }

  /// Returns CFU/mL calculated from [adjustedCount] (AI + manual corrections).
  double get adjustedCfuPerML {
    if (adjustedCount <= 0) return 0;
    // Reuse the same dilution/volume parsing logic via cfuPerML's internals
    final ratio = adjustedCount / colonyCount;
    return cfuPerML * ratio;
  }

  /// Returns formatted CFU/mL string.
  String get cfuPerMLLabel {
    final cfu = cfuPerML;
    if (cfu == 0) return '0';
    if (cfu >= 1000000) return '${(cfu / 1000000).toStringAsFixed(1)} × 10⁶';
    if (cfu >= 1000) return '${(cfu / 1000).toStringAsFixed(1)} × 10³';
    return cfu.toStringAsFixed(0);
  }

  /// Returns formatted adjusted CFU/mL string.
  String get adjustedCfuPerMLLabel {
    final cfu = adjustedCfuPerML;
    if (cfu == 0) return '0';
    if (cfu >= 1000000) return '${(cfu / 1000000).toStringAsFixed(1)} × 10⁶';
    if (cfu >= 1000) return '${(cfu / 1000).toStringAsFixed(1)} × 10³';
    return cfu.toStringAsFixed(0);
  }

  /// Count of bubble detections.
  int get bubbleCount =>
      detections.where((d) => d.className == 'bubble').length;

  /// Count of dust detections.
  int get dustCount =>
      detections.where((d) => d.className == 'dust').length;

  /// Count of crack detections.
  int get crackCount =>
      detections.where((d) => d.className == 'crack').length;

  /// Average confidence across all detections. Returns 0 if no detections.
  double get averageConfidence {
    if (detections.isEmpty) return 0.0;
    final total = detections.fold<double>(0.0, (sum, d) => sum + d.confidence);
    return total / detections.length;
  }

  /// Returns a map of class names to their counts.
  Map<String, int> get classCounts {
    final counts = <String, int>{};
    for (final detection in detections) {
      counts[detection.className] = (counts[detection.className] ?? 0) + 1;
    }
    return counts;
  }

  /// Returns a map of class names to their average confidence.
  Map<String, double> get classAverageConfidence {
    final confidences = <String, List<double>>{};
    for (final detection in detections) {
      confidences.putIfAbsent(detection.className, () => []);
      confidences[detection.className]!.add(detection.confidence);
    }
    return confidences.map((key, values) {
      final avg = values.reduce((a, b) => a + b) / values.length;
      return MapEntry(key, avg);
    });
  }

  /// Returns detections filtered by a minimum confidence threshold.
  List<DetectionResult> filteredByConfidence(double threshold) {
    return detections.where((d) => d.confidence >= threshold).toList();
  }

  /// Returns detections filtered by class name.
  List<DetectionResult> filteredByClass(String className) {
    return detections.where((d) => d.className == className).toList();
  }

  /// Returns the colony count severity level.
  String get colonySeverity {
    return AppConfig.getColonySeverity(colonyCount);
  }

  /// Returns high-confidence detections (>= 0.80).
  List<DetectionResult> get highConfidenceDetections =>
      filteredByConfidence(AppConfig.highConfidence);

  /// Returns medium-confidence detections (0.50 - 0.80).
  List<DetectionResult> get mediumConfidenceDetections => detections
      .where((d) =>
          d.confidence >= AppConfig.mediumConfidence &&
          d.confidence < AppConfig.highConfidence)
      .toList();

  /// Returns low-confidence detections (< 0.50).
  List<DetectionResult> get lowConfidenceDetections =>
      detections.where((d) => d.confidence < AppConfig.mediumConfidence).toList();

  /// Creates an AnalysisResult from a JSON map.
  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> detectionsJson = json['detections'] as List<dynamic>? ?? [];
    return AnalysisResult(
      id: json['id'] as String? ?? '',
      sampleId: json['sample_id'] as String? ?? '',
      imagePath: json['image_path'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      processingTime: json['processing_time_ms'] != null
          ? Duration(milliseconds: (json['processing_time_ms'] as num).toInt())
          : Duration.zero,
      detections: detectionsJson
          .map((d) => DetectionResult.fromJson(d as Map<String, dynamic>))
          .toList(),
      imageWidth: (json['image_width'] as num?)?.toInt() ?? 0,
      imageHeight: (json['image_height'] as num?)?.toInt() ?? 0,
      modelVersion: json['model_version'] as String? ?? 'YOLOv8-v4',
      mediaType: json['media_type'] as String? ?? '',
      dilution: json['dilution'] as String? ?? '',
      inoculationMethod: json['inoculation_method'] as String? ?? '',
      inoculumVolume: json['inoculum_volume'] as String? ?? '',
      sampleType: json['sample_type'] as String? ?? '',
      plateReplicate: json['plate_replicate'] as String? ?? '',
      samplingTime: json['sampling_time'] as String? ?? '',
      samplingLocation: json['sampling_location'] as String? ?? '',
      samplingOfficer: json['sampling_officer'] as String? ?? '',
      incubatorEntryTime: json['incubator_entry_time'] as String? ?? '',
      incubatorTemp: json['incubator_temp'] as String? ?? '',
      incubationTime: json['incubation_time'] as String? ?? '',
      incubationCondition: json['incubation_condition'] as String? ?? '',
      incubatorId: json['incubator_id'] as String? ?? '',
      diluent: json['diluent'] as String? ?? '',
      mediaLot: json['media_lot'] as String? ?? '',
      analystName: json['analyst_name'] as String? ?? '',
      morphologyNotes: json['morphology_notes'] as String? ?? '',
      added: (json['added'] as num?)?.toInt() ?? 0,
      removed: (json['removed'] as num?)?.toInt() ?? 0,
    );
  }

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sample_id': sampleId,
      'image_path': imagePath,
      'timestamp': timestamp.toIso8601String(),
      'processing_time_ms': processingTime.inMilliseconds,
      'detections': detections.map((d) => d.toJson()).toList(),
      'image_width': imageWidth,
      'image_height': imageHeight,
      'model_version': modelVersion,
      'media_type': mediaType,
      'dilution': dilution,
      'inoculation_method': inoculationMethod,
      'inoculum_volume': inoculumVolume,
      'sample_type': sampleType,
      'plate_replicate': plateReplicate,
      'sampling_time': samplingTime,
      'sampling_location': samplingLocation,
      'sampling_officer': samplingOfficer,
      'incubator_entry_time': incubatorEntryTime,
      'incubator_temp': incubatorTemp,
      'incubation_time': incubationTime,
      'incubation_condition': incubationCondition,
      'incubator_id': incubatorId,
      'diluent': diluent,
      'media_lot': mediaLot,
      'analyst_name': analystName,
      'morphology_notes': morphologyNotes,
      'added': added,
      'removed': removed,
    };
  }

  /// Creates a copy with optional parameter overrides.
  AnalysisResult copyWith({
    String? id,
    String? sampleId,
    String? imagePath,
    DateTime? timestamp,
    Duration? processingTime,
    List<DetectionResult>? detections,
    int? imageWidth,
    int? imageHeight,
    String? modelVersion,
    String? mediaType,
    String? dilution,
    String? inoculationMethod,
    String? inoculumVolume,
    String? sampleType,
    String? plateReplicate,
    String? samplingTime,
    String? samplingLocation,
    String? samplingOfficer,
    String? incubatorEntryTime,
    String? incubatorTemp,
    String? incubationTime,
    String? incubationCondition,
    String? incubatorId,
    String? diluent,
    String? mediaLot,
    String? analystName,
    String? morphologyNotes,
    String? ambientTemperature,
    String? ambientHumidity,
    String? laboratory,
    int? added,
    int? removed,
  }) {
    return AnalysisResult(
      id: id ?? this.id,
      sampleId: sampleId ?? this.sampleId,
      imagePath: imagePath ?? this.imagePath,
      timestamp: timestamp ?? this.timestamp,
      processingTime: processingTime ?? this.processingTime,
      detections: detections ?? this.detections,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      modelVersion: modelVersion ?? this.modelVersion,
      mediaType: mediaType ?? this.mediaType,
      dilution: dilution ?? this.dilution,
      inoculationMethod: inoculationMethod ?? this.inoculationMethod,
      inoculumVolume: inoculumVolume ?? this.inoculumVolume,
      sampleType: sampleType ?? this.sampleType,
      plateReplicate: plateReplicate ?? this.plateReplicate,
      samplingTime: samplingTime ?? this.samplingTime,
      samplingLocation: samplingLocation ?? this.samplingLocation,
      samplingOfficer: samplingOfficer ?? this.samplingOfficer,
      incubatorEntryTime: incubatorEntryTime ?? this.incubatorEntryTime,
      incubatorTemp: incubatorTemp ?? this.incubatorTemp,
      incubationTime: incubationTime ?? this.incubationTime,
      incubationCondition: incubationCondition ?? this.incubationCondition,
      incubatorId: incubatorId ?? this.incubatorId,
      diluent: diluent ?? this.diluent,
      mediaLot: mediaLot ?? this.mediaLot,
      analystName: analystName ?? this.analystName,
      morphologyNotes: morphologyNotes ?? this.morphologyNotes,
      ambientTemperature: ambientTemperature ?? this.ambientTemperature,
      ambientHumidity: ambientHumidity ?? this.ambientHumidity,
      laboratory: laboratory ?? this.laboratory,
      added: added ?? this.added,
      removed: removed ?? this.removed,
    );
  }

  @override
  String toString() {
    return 'AnalysisResult(id: $id, colonies: $colonyCount, total: $totalDetections, avgConf: ${(averageConfidence * 100).toStringAsFixed(1)}%)';
  }
}

/// Represents sample information for a microbiology plate.
class SampleInfo {
  final String id;
  final String sampleId;
  final String mediaType;
  final DateTime incubationDate;
  final String dilution;
  final String operatorName;
  final String laboratoryName;
  final String status; // pending, processing, completed, reviewed, approved
  final DateTime? analyzedAt;
  final AnalysisResult? result;

  SampleInfo({
    required this.id,
    required this.sampleId,
    required this.mediaType,
    required this.incubationDate,
    required this.dilution,
    required this.operatorName,
    required this.laboratoryName,
    this.status = 'pending',
    this.analyzedAt,
    this.result,
  });

  /// Whether the sample has been analyzed.
  bool get isAnalyzed => result != null;

  /// Whether the sample has been reviewed.
  bool get isReviewed => status == 'reviewed' || status == 'approved';

  /// Whether the sample is approved.
  bool get isApproved => status == 'approved';

  /// Whether the sample is currently being processed.
  bool get isProcessing => status == 'processing';

  /// Whether the sample is pending analysis.
  bool get isPending => status == 'pending';

  /// Returns the colony count from the result, or 0 if not analyzed.
  int get colonyCount => result?.colonyCount ?? 0;

  /// Returns the CFU/mL based on dilution and colony count.
  /// Assumes standard 100µL spread plate method.
  double get cfuPerML {
    if (colonyCount == 0) return 0;
    double dilutionFactor;
    try {
      // Parse dilution like "10^-3" or "1:1000"
      final dilutionStr = dilution.trim();
      if (dilutionStr.startsWith('10^-')) {
        final exponent = int.parse(dilutionStr.substring(4));
        dilutionFactor = 1 / math.pow(10, exponent);
      } else if (dilutionStr.startsWith('1:')) {
        final divisor = int.parse(dilutionStr.substring(2));
        dilutionFactor = 1 / divisor;
      } else {
        dilutionFactor = double.parse(dilutionStr);
      }
    } catch (_) {
      dilutionFactor = 1.0;
    }
    // For 100µL (0.1 mL) spread plate
    return colonyCount / (dilutionFactor * 0.1);
  }



  /// Returns formatted CFU/mL string.
  String get cfuPerMLLabel {
    final cfu = cfuPerML;
    if (cfu == 0) return '0';
    if (cfu >= 1000000) return '${(cfu / 1000000).toStringAsFixed(1)} × 10⁶';
    if (cfu >= 1000) return '${(cfu / 1000).toStringAsFixed(1)} × 10³';
    return cfu.toStringAsFixed(0);
  }

  /// Returns the status color.
  Color get statusColor {
    switch (status) {
      case 'pending':
        return AppColors.statusIdle;
      case 'processing':
        return AppColors.statusProcessing;
      case 'completed':
        return AppColors.statusOnline;
      case 'reviewed':
        return AppColors.statusStandby;
      case 'approved':
        return AppColors.success;
      default:
        return AppColors.textTertiary;
    }
  }

  /// Returns the display label for the status.
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'processing':
        return 'Memproses';
      case 'completed':
        return 'Selesai';
      case 'reviewed':
        return 'Ditinjau';
      case 'approved':
        return 'Disetujui';
      default:
        return status.toUpperCase();
    }
  }

  /// Creates a SampleInfo from a JSON map.
  factory SampleInfo.fromJson(Map<String, dynamic> json) {
    return SampleInfo(
      id: json['id'] as String,
      sampleId: json['sample_id'] as String,
      mediaType: json['media_type'] as String? ?? 'PCA',
      incubationDate: json['incubation_date'] != null
          ? DateTime.parse(json['incubation_date'] as String)
          : DateTime.now(),
      dilution: json['dilution'] as String? ?? '10^-1',
      operatorName: json['operator_name'] as String? ?? '',
      laboratoryName: json['laboratory_name'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      analyzedAt: json['analyzed_at'] != null
          ? DateTime.parse(json['analyzed_at'] as String)
          : null,
      result: json['result'] != null
          ? AnalysisResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sample_id': sampleId,
      'media_type': mediaType,
      'incubation_date': incubationDate.toIso8601String(),
      'dilution': dilution,
      'operator_name': operatorName,
      'laboratory_name': laboratoryName,
      'status': status,
      'analyzed_at': analyzedAt?.toIso8601String(),
      'result': result?.toJson(),
    };
  }

  /// Creates a copy with optional parameter overrides.
  SampleInfo copyWith({
    String? id,
    String? sampleId,
    String? mediaType,
    DateTime? incubationDate,
    String? dilution,
    String? operatorName,
    String? laboratoryName,
    String? status,
    DateTime? analyzedAt,
    AnalysisResult? result,
  }) {
    return SampleInfo(
      id: id ?? this.id,
      sampleId: sampleId ?? this.sampleId,
      mediaType: mediaType ?? this.mediaType,
      incubationDate: incubationDate ?? this.incubationDate,
      dilution: dilution ?? this.dilution,
      operatorName: operatorName ?? this.operatorName,
      laboratoryName: laboratoryName ?? this.laboratoryName,
      status: status ?? this.status,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      result: result ?? this.result,
    );
  }

  @override
  String toString() {
    return 'SampleInfo(id: $id, sampleId: $sampleId, status: $status)';
  }
}

/// Represents a batch of samples for organized analysis.
class BatchInfo {
  final String id;
  final String name;
  final String project;
  final DateTime createdAt;
  final List<SampleInfo> samples;

  BatchInfo({
    required this.id,
    required this.name,
    required this.project,
    required this.createdAt,
    required this.samples,
  });

  /// Number of completed samples.
  int get completedCount =>
      samples.where((s) => s.status == 'completed').length;

  /// Total number of samples.
  int get totalCount => samples.length;

  /// Completion rate as a value between 0.0 and 1.0.
  double get completionRate =>
      totalCount > 0 ? completedCount / totalCount : 0.0;

  /// Number of pending samples.
  int get pendingCount =>
      samples.where((s) => s.status == 'pending').length;

  /// Number of processing samples.
  int get processingCount =>
      samples.where((s) => s.status == 'processing').length;

  /// Number of reviewed samples.
  int get reviewedCount =>
      samples.where((s) => s.status == 'reviewed').length;

  /// Number of approved samples.
  int get approvedCount =>
      samples.where((s) => s.status == 'approved').length;

  /// Whether the batch is fully completed.
  bool get isFullyCompleted => completedCount == totalCount;

  /// Whether the batch is fully approved.
  bool get isFullyApproved => approvedCount == totalCount;

  /// Total colony count across all analyzed samples.
  int get totalColonyCount =>
      samples.fold<int>(0, (sum, s) => sum + s.colonyCount);

  /// Average colony count per analyzed sample.
  double get averageColonyCount {
    final analyzedSamples = samples.where((s) => s.isAnalyzed).toList();
    if (analyzedSamples.isEmpty) return 0.0;
    return totalColonyCount / analyzedSamples.length;
  }

  /// Returns the completion percentage as a formatted string.
  String get completionPercentage =>
      '${(completionRate * 100).toStringAsFixed(0)}%';

  /// Creates a BatchInfo from a JSON map.
  factory BatchInfo.fromJson(Map<String, dynamic> json) {
    final List<dynamic> samplesJson = json['samples'] as List<dynamic>? ?? [];
    return BatchInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      project: json['project'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      samples: samplesJson
          .map((s) => SampleInfo.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'project': project,
      'created_at': createdAt.toIso8601String(),
      'samples': samples.map((s) => s.toJson()).toList(),
    };
  }

  /// Creates a copy with optional parameter overrides.
  BatchInfo copyWith({
    String? id,
    String? name,
    String? project,
    DateTime? createdAt,
    List<SampleInfo>? samples,
  }) {
    return BatchInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      project: project ?? this.project,
      createdAt: createdAt ?? this.createdAt,
      samples: samples ?? this.samples,
    );
  }

  @override
  String toString() {
    return 'BatchInfo(id: $id, name: $name, completion: $completionPercentage)';
  }
}
