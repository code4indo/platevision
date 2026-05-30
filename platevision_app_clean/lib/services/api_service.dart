import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:platevision_ai/config/app_config.dart';
import 'package:platevision_ai/models/detection_result.dart';

// ============================================================================
// Custom Exceptions
// ============================================================================

/// Base exception for all API-related errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? endpoint;
  final dynamic originalError;

  const ApiException({
    required this.message,
    this.statusCode,
    this.endpoint,
    this.originalError,
  });

  @override
  String toString() =>
      'ApiException($statusCode): $message${endpoint != null ? ' [$endpoint]' : ''}';
}

/// Thrown when the API server is unreachable or returns a server error.
class ServerException extends ApiException {
  const ServerException({
    required super.message,
    super.statusCode,
    super.endpoint,
    super.originalError,
  });
}

/// Thrown when the request is malformed or unauthorized (4xx errors).
class ClientException extends ApiException {
  const ClientException({
    required super.message,
    super.statusCode,
    super.endpoint,
    super.originalError,
  });
}

/// Thrown when the request times out.
class TimeoutException extends ApiException {
  const TimeoutException({
    required super.message,
    super.endpoint,
    super.originalError,
  });
}

/// Thrown when there is no network connectivity.
class NetworkException extends ApiException {
  const NetworkException({
    required super.message,
    super.endpoint,
    super.originalError,
  });
}

/// Thrown when the API response cannot be parsed into expected models.
class ParseException extends ApiException {
  const ParseException({
    required super.message,
    super.endpoint,
    super.originalError,
  });
}

/// Thrown when the uploaded image is invalid or unsupported.
class InvalidImageException extends ApiException {
  const InvalidImageException({
    required super.message,
    super.statusCode,
    super.endpoint,
    super.originalError,
  });
}

// ============================================================================
// API Health Status
// ============================================================================

/// Represents the health status of the API server.
class ApiHealthStatus {
  final bool isHealthy;
  final String status;
  final String? modelVersion;
  final Duration? responseTime;
  final DateTime checkedAt;

  const ApiHealthStatus({
    required this.isHealthy,
    required this.status,
    this.modelVersion,
    this.responseTime,
    required this.checkedAt,
  });

  @override
  String toString() =>
      'ApiHealthStatus(healthy: $isHealthy, status: $status, responseTime: ${responseTime?.inMilliseconds}ms)';
}

// ============================================================================
// Prediction Response
// ============================================================================

/// Parsed response from the prediction API.
class PredictionResponse {
  final List<DetectionResult> detections;
  final int imageWidth;
  final int imageHeight;
  final Duration processingTime;
  final String modelVersion;
  final Map<String, dynamic>? rawResponse;

  const PredictionResponse({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
    required this.processingTime,
    this.modelVersion = 'YOLOv8-v4',
    this.rawResponse,
  });

  /// Total number of detections.
  int get totalDetections => detections.length;

  @override
  String toString() =>
      'PredictionResponse(detections: $totalDetections, processingTime: ${processingTime.inMilliseconds}ms)';
}

// ============================================================================
// API Service
// ============================================================================

/// Service for communicating with the PlateVisionAI backend API.
///
/// Handles image upload for YOLO detection, health checks, and response parsing.
/// Uses Dio for HTTP communication with interceptors for auth, logging, and error handling.
class ApiService {
  late final Dio _dio;
  String? _authToken;

  /// Singleton instance.
  static final ApiService _instance = ApiService._internal();

  /// Factory constructor returns the singleton instance.
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout * 2,
        sendTimeout: AppConfig.apiTimeout * 2,
        headers: {
          'Accept': 'application/json',
        },
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _setupInterceptors();
  }

  // --------------------------------------------------------------------------
  // Interceptors
  // --------------------------------------------------------------------------

  void _setupInterceptors() {
    // Auth interceptor - adds token to requests if available
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null && _authToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        handler.next(options);
      },
    ));

    // Logging interceptor for debugging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
      logPrint: (obj) {
        // In production, route to proper logging system
        // ignore: avoid_print
        print('[API] $obj');
      },
    ));

    // Error handling interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        final apiException = _mapDioException(error);
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            error: apiException,
          ),
        );
      },
    ));
  }

  // --------------------------------------------------------------------------
  // Auth Token Management
  // --------------------------------------------------------------------------

  /// Sets the authentication token for subsequent requests.
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Clears the authentication token.
  void clearAuthToken() {
    _authToken = null;
  }

  /// Returns whether an auth token is currently set.
  bool get hasAuthToken => _authToken != null && _authToken!.isNotEmpty;

  // --------------------------------------------------------------------------
  // Health Check
  // --------------------------------------------------------------------------

  /// Checks the health of the API server.
  ///
  /// Returns [ApiHealthStatus] with connectivity and model information.
  Future<ApiHealthStatus> checkHealth() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get(
        AppConfig.apiHealthEndpoint,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = response.data;
        return ApiHealthStatus(
          isHealthy: true,
          status: data['status'] as String? ?? 'healthy',
          modelVersion: data['model_version'] as String?,
          responseTime: stopwatch.elapsed,
          checkedAt: DateTime.now(),
        );
      } else {
        return ApiHealthStatus(
          isHealthy: false,
          status: 'unhealthy',
          responseTime: stopwatch.elapsed,
          checkedAt: DateTime.now(),
        );
      }
    } on DioException catch (_) {
      stopwatch.stop();
      return ApiHealthStatus(
        isHealthy: false,
        status: 'unreachable',
        responseTime: stopwatch.elapsed,
        checkedAt: DateTime.now(),
      );
    } catch (_) {
      stopwatch.stop();
      return ApiHealthStatus(
        isHealthy: false,
        status: 'error',
        responseTime: stopwatch.elapsed,
        checkedAt: DateTime.now(),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Image Prediction
  // --------------------------------------------------------------------------

  /// Sends an image file for YOLO object detection analysis.
  ///
  /// [imagePath] - Local path to the image file.
  /// [confidenceThreshold] - Minimum confidence for detections (default: 0.25).
  /// [iouThreshold] - IoU threshold for NMS (default: 0.45).
  ///
  /// Returns a [PredictionResponse] with parsed detection results.
  Future<PredictionResponse> predictImage({
    required String imagePath,
    double confidenceThreshold = AppConfig.confidenceThreshold,
    double iouThreshold = AppConfig.iouThreshold,
  }) async {
    // Validate the image file
    final file = File(imagePath);
    if (!await file.exists()) {
      throw InvalidImageException(
        message: 'File gambar tidak ditemukan: $imagePath',
        endpoint: AppConfig.apiPredictEndpoint,
      );
    }

    final fileSize = await file.length();
    final maxSizeBytes = AppConfig.maxImageSizeMB * 1024 * 1024;
    if (fileSize > maxSizeBytes) {
      throw InvalidImageException(
        message:
            'Ukuran file melebihi batas ${AppConfig.maxImageSizeMB}MB (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB)',
        endpoint: AppConfig.apiPredictEndpoint,
      );
    }

    // Validate file extension
    final extension = imagePath.split('.').last.toLowerCase();
    if (!AppConfig.isSupportedFormat(extension)) {
      throw InvalidImageException(
        message:
            'Format file tidak didukung: .$extension. Didukung: ${AppConfig.supportedFormats.join(', ')}',
        endpoint: AppConfig.apiPredictEndpoint,
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      // Build multipart form data
      final fileName = imagePath.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imagePath,
          filename: fileName,
        ),
        'conf_threshold': confidenceThreshold.toString(),
        'iou_threshold': iouThreshold.toString(),
      });

      // Send the prediction request
      final response = await _dio.post(
        AppConfig.apiPredictEndpoint,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          responseType: ResponseType.json,
          receiveTimeout: AppConfig.apiTimeout * 3,
          sendTimeout: AppConfig.apiTimeout * 3,
        ),
      );

      stopwatch.stop();

      // Parse the response
      return _parsePredictionResponse(
        response.data,
        stopwatch.elapsed,
      );
    } on DioException catch (e) {
      stopwatch.stop();
      throw _mapDioException(e);
    } catch (e) {
      stopwatch.stop();
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Kesalahan tak terduga: ${e.toString()}',
        endpoint: AppConfig.apiPredictEndpoint,
        originalError: e,
      );
    }
  }

  /// Sends raw image bytes for prediction.
  ///
  /// [imageBytes] - Raw bytes of the image.
  /// [fileName] - Name for the uploaded file.
  /// [confidenceThreshold] - Minimum confidence for detections.
  /// [iouThreshold] - IoU threshold for NMS.
  Future<PredictionResponse> predictImageBytes({
    required List<int> imageBytes,
    required String fileName,
    double confidenceThreshold = AppConfig.confidenceThreshold,
    double iouThreshold = AppConfig.iouThreshold,
  }) async {
    final maxSizeBytes = AppConfig.maxImageSizeMB * 1024 * 1024;
    if (imageBytes.length > maxSizeBytes) {
      throw InvalidImageException(
        message:
            'Ukuran file melebihi batas ${AppConfig.maxImageSizeMB}MB',
        endpoint: AppConfig.apiPredictEndpoint,
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          imageBytes,
          filename: fileName,
        ),
        'conf_threshold': confidenceThreshold.toString(),
        'iou_threshold': iouThreshold.toString(),
      });

      final response = await _dio.post(
        AppConfig.apiPredictEndpoint,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          responseType: ResponseType.json,
          receiveTimeout: AppConfig.apiTimeout * 3,
          sendTimeout: AppConfig.apiTimeout * 3,
        ),
      );

      stopwatch.stop();

      return _parsePredictionResponse(
        response.data,
        stopwatch.elapsed,
      );
    } on DioException catch (e) {
      stopwatch.stop();
      throw _mapDioException(e);
    } catch (e) {
      stopwatch.stop();
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Kesalahan tak terduga: ${e.toString()}',
        endpoint: AppConfig.apiPredictEndpoint,
        originalError: e,
      );
    }
  }

  // --------------------------------------------------------------------------
  // Response Parsing
  // --------------------------------------------------------------------------

  /// Parses the raw API response into a PredictionResponse.
  ///
  /// Handles multiple response formats from the Gradio/YOLO backend:
  /// 1. {"data": [{"detections": [...], "image_width": 640, ...}]}
  /// 2. {"detections": [...], "image_width": 640, ...}
  /// 3. {"data": [[x1,y1,x2,y2,conf,class], ...]}
  /// 4. {"results": [[x1,y1,x2,y2,conf,class], ...]}
  PredictionResponse _parsePredictionResponse(
    dynamic responseData,
    Duration processingTime,
  ) {
    try {
      Map<String, dynamic> data;

      // Unwrap Gradio-style response: {"data": [...]}
      if (responseData is Map && responseData.containsKey('data')) {
        final innerData = responseData['data'];
        if (innerData is List && innerData.isNotEmpty) {
          final firstItem = innerData[0];
          if (firstItem is Map) {
            data = Map<String, dynamic>.from(firstItem);
          } else if (firstItem is List) {
            // data is a list of detection arrays
            return _parseRawDetectionList(
              innerData.cast<List<dynamic>>(),
              processingTime,
              responseData,
            );
          } else {
            data = {'detections': []};
          }
        } else {
          data = {'detections': []};
        }
      } else if (responseData is Map) {
        data = Map<String, dynamic>.from(responseData);
      } else if (responseData is List) {
        // Direct list of detections
        return _parseRawDetectionList(
          responseData.cast<List<dynamic>>(),
          processingTime,
          null,
        );
      } else {
        throw const ParseException(
          message: 'Format respons API tidak dikenali',
        );
      }

      // Parse detections from the data map
      final List<DetectionResult> detections = [];

      // Try multiple possible keys for detections
      final detectionKeys = [
        'detections',
        'predictions',
        'results',
        'boxes',
        'output',
      ];

      List<dynamic>? detectionList;
      for (final key in detectionKeys) {
        if (data[key] != null) {
          detectionList = data[key] as List<dynamic>;
          break;
        }
      }

      if (detectionList != null) {
        for (final item in detectionList) {
          if (item is Map<String, dynamic>) {
            try {
              detections.add(DetectionResult.fromJson(item));
            } catch (_) {
              // Skip malformed detection entries
              continue;
            }
          } else if (item is List) {
            try {
              detections.add(DetectionResult.fromYoloList(item));
            } catch (_) {
              continue;
            }
          }
        }
      }

      // Extract image dimensions
      final imageWidth = (data['image_width'] as num?)?.toInt() ??
          (data['width'] as num?)?.toInt() ??
          0;
      final imageHeight = (data['image_height'] as num?)?.toInt() ??
          (data['height'] as num?)?.toInt() ??
          0;

      final modelVersion = data['model_version'] as String? ??
          data['model'] as String? ??
          'YOLOv8-v4';

      return PredictionResponse(
        detections: detections,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        processingTime: processingTime,
        modelVersion: modelVersion,
        rawResponse: Map<String, dynamic>.from(responseData),
      );
    } catch (e) {
      if (e is ParseException) rethrow;
      throw ParseException(
        message: 'Gagal memproses respons API: ${e.toString()}',
        endpoint: AppConfig.apiPredictEndpoint,
        originalError: e,
      );
    }
  }

  /// Parses a raw list of detection arrays (YOLO format).
  PredictionResponse _parseRawDetectionList(
    List<List<dynamic>> rawDetections,
    Duration processingTime,
    dynamic rawResponse,
  ) {
    final detections = <DetectionResult>[];

    for (final item in rawDetections) {
      try {
        if (item.length >= 5) {
          detections.add(DetectionResult.fromYoloList(item));
        }
      } catch (_) {
        continue;
      }
    }

    return PredictionResponse(
      detections: detections,
      imageWidth: 0,
      imageHeight: 0,
      processingTime: processingTime,
      modelVersion: 'YOLOv8-v4',
      rawResponse: rawResponse is Map
          ? Map<String, dynamic>.from(rawResponse)
          : null,
    );
  }

  // --------------------------------------------------------------------------
  // Exception Mapping
  // --------------------------------------------------------------------------

  /// Maps a DioException to a specific ApiException.
  ApiException _mapDioException(DioException e) {
    final endpoint = e.requestOptions.path;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(
          message:
              'Waktu koneksi habis. Server tidak merespons dalam waktu yang ditentukan.',
          endpoint: endpoint,
          originalError: e,
        );

      case DioExceptionType.connectionError:
        return NetworkException(
          message:
              'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
          endpoint: endpoint,
          originalError: e,
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;

        if (statusCode != null && statusCode >= 500) {
          return ServerException(
            message: _extractErrorMessage(data) ??
                'Kesalahan server internal ($statusCode). Coba lagi nanti.',
            statusCode: statusCode,
            endpoint: endpoint,
            originalError: e,
          );
        }

        if (statusCode == 401) {
          return ClientException(
            message:
                'Autentikasi gagal. Silakan masuk kembali.',
            statusCode: statusCode,
            endpoint: endpoint,
            originalError: e,
          );
        }

        if (statusCode == 403) {
          return ClientException(
            message:
                'Akses ditolak. Anda tidak memiliki izin untuk operasi ini.',
            statusCode: statusCode,
            endpoint: endpoint,
            originalError: e,
          );
        }

        if (statusCode == 413) {
          return InvalidImageException(
            message:
                'File terlalu besar. Ukuran maksimum ${AppConfig.maxImageSizeMB}MB.',
            statusCode: statusCode,
            endpoint: endpoint,
            originalError: e,
          );
        }

        if (statusCode == 422) {
          return ClientException(
            message: _extractErrorMessage(data) ??
                'Data yang dikirim tidak valid.',
            statusCode: statusCode,
            endpoint: endpoint,
            originalError: e,
          );
        }

        return ClientException(
          message: _extractErrorMessage(data) ??
              'Kesalahan klien: $statusCode',
          statusCode: statusCode,
          endpoint: endpoint,
          originalError: e,
        );

      case DioExceptionType.cancel:
        return const ClientException(
          message: 'Permintaan dibatalkan.',
        );

      case DioExceptionType.badCertificate:
        return const NetworkException(
          message:
              'Sertifikat keamanan server tidak valid. Koneksi ditolak.',
        );

      case DioExceptionType.unknown:
        if (e.error != null && e.error.toString().contains('SocketException')) {
          return NetworkException(
            message:
                'Tidak ada koneksi internet. Periksa jaringan Anda.',
            endpoint: endpoint,
            originalError: e,
          );
        }
        return ApiException(
          message: 'Kesalahan tak terduga: ${e.message ?? e.toString()}',
          endpoint: endpoint,
          originalError: e,
        );
    }
  }

  /// Extracts a human-readable error message from the response data.
  String? _extractErrorMessage(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      return data['detail'] as String? ??
          data['message'] as String? ??
          data['error'] as String? ??
          data['msg'] as String?;
    }
    if (data is String) return data;
    return null;
  }

  // --------------------------------------------------------------------------
  // Analysis Persistence (Backend Storage)
  // --------------------------------------------------------------------------

  /// Saves an analysis result to the backend server.
  Future<Map<String, dynamic>> saveAnalysis(
      Map<String, dynamic> analysisData) async {
    try {
      final response = await _dio.post(
        '/api/analyses',
        data: analysisData,
        options: Options(
          receiveTimeout: AppConfig.apiTimeout,
          sendTimeout: AppConfig.apiTimeout,
        ),
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : {'status': 'saved'};
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Fetches saved analyses from the backend with optional filters.
  Future<Map<String, dynamic>> fetchAnalyses({
    int limit = 50,
    int offset = 0,
    String? batchId,
    String? mediaType,
    String? operatorName,
  }) async {
    try {
      final params = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (batchId != null) params['batch_id'] = batchId;
      if (mediaType != null) params['media_type'] = mediaType;
      if (operatorName != null) params['operator_name'] = operatorName;

      final response = await _dio.get(
        '/api/analyses',
        queryParameters: params,
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : {'analyses': [], 'total': 0};
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Fetches aggregated dashboard statistics from the backend.
  Future<Map<String, dynamic>> fetchAnalysisOverview() async {
    try {
      final response = await _dio.get(
        '/api/analyses/stats/overview',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : {};
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Fetches a single analysis by its ID.
  Future<Map<String, dynamic>> fetchAnalysisById(String analysisId) async {
    try {
      final response = await _dio.get('/api/analyses/$analysisId');
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : {};
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Deletes an analysis by its ID from the backend.
  Future<void> deleteAnalysisById(String analysisId) async {
    try {
      await _dio.delete('/api/analyses/$analysisId');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // --------------------------------------------------------------------------
  // Utility Methods
  // --------------------------------------------------------------------------

  /// Generates a unique ID for analysis results.
  static String generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(9999).toString().padLeft(4, '0');
    return 'ANL-$timestamp-$random';
  }
}
