import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:cyber_nova/config/app_config.dart';
import 'package:cyber_nova/models/inspection_model.dart';
import 'package:cyber_nova/services/gemini_vision_service.dart';
import 'package:cyber_nova/services/inspection_db.dart';
import 'package:cyber_nova/services/rule_engine.dart';
import 'package:cyber_nova/utils/app_theme.dart';

class ApiException implements Exception {
  final String userMessage;
  final bool backendUnavailable;

  ApiException(this.userMessage, {this.backendUnavailable = false});

  @override
  String toString() => userMessage;
}

class ApiService {
  Future<bool> isHealthy() async {
    try {
      final response = await http
          .get(Uri.parse(AppConfig.healthEndpoint))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<InspectionModel> scanLabel({
    required Uint8List imageBytes,
    required String filename,
    bool useSampleAsset = false,
  }) async {
    return scanLabelMulti(
      productImages: [
        ProductImage(
          bytes: imageBytes,
          filename: filename,
          source: ScanSource.gallery,
          index: 1,
        ),
      ],
      useSampleAsset: useSampleAsset,
    );
  }

  Future<InspectionModel> scanLabelMulti({
    required List<ProductImage> productImages,
    bool useSampleAsset = false,
  }) async {
    if (productImages.isEmpty) {
      throw ApiException('Please add at least one product image.');
    }
    if (AppConfig.preferLocalMode) {
      try {
        return await _runLocalPathB(
          productImages: productImages,
          useSampleAsset: useSampleAsset,
        );
      } on ApiException {
        rethrow;
      } catch (_) {
        final healthy = await isHealthy();
        if (healthy) {
          try {
            return await _scanLabelBackend(
              productImages: productImages,
              useSampleAsset: useSampleAsset,
            );
          } on ApiException {
            rethrow;
          } catch (_) {
            throw ApiException(
              'AI analysis could not be completed. Please try again.',
            );
          }
        }
        throw ApiException(
          'Unable to connect to the inspection service. Please try again.',
          backendUnavailable: true,
        );
      }
    }
    try {
      return await _scanLabelBackend(
        productImages: productImages,
        useSampleAsset: useSampleAsset,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Unable to connect to the inspection service. Please try again.',
        backendUnavailable: true,
      );
    }
  }

  Future<InspectionModel> _runLocalPathB({
    required List<ProductImage> productImages,
    required bool useSampleAsset,
  }) async {
    Map<String, dynamic> extraction;
    try {
      extraction = await GeminiVisionService.extractMulti(
        images: productImages
            .map((p) => (bytes: p.bytes, filename: p.filename))
            .toList(),
      );
    } on GeminiVisionException catch (e) {
      final userMsg = _userMessageForGeminiCode(e.code, e.message);
      throw ApiException(userMsg);
    } catch (_) {
      throw ApiException(
        'AI analysis could not be completed. Please try again.',
      );
    }

    final inspectionId = _generateInspectionId();
    final eval = RuleEngine.evaluateExtraction(extraction, inspectionId);
    final fakeApiPayload = eval.toApiPayload(inspectionId);

    final model = InspectionModel.fromApi(
      fakeApiPayload,
      productImages: productImages,
      useSampleAsset: useSampleAsset,
    );

    try {
      await InspectionDb.instance.saveInspection(model);
    } catch (_) {}

    return model;
  }

  String _generateInspectionId() {
    final rand = Random();
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final suffix = List.generate(4, (_) => rand.nextInt(10)).join();
    return 'CN-$stamp-$suffix';
  }

  String _userMessageForGeminiCode(String code, String fallback) {
    switch (code) {
      case 'no_images':
        return 'Please add at least one product image.';
      case 'invalid_api_key':
        return 'Gemini API key is invalid. Please configure a valid key.';
      case 'rate_limit':
        return 'The analysis service is busy. Please try again shortly.';
      case 'content_blocked':
        return 'The image could not be processed due to content restrictions.';
      case 'all_models_unavailable':
        return 'All Gemini models are currently unavailable due to high demand. Wait 1-2 minutes and try again.';
      case 'invalid_gemini_response':
        return 'AI analysis could not be completed. The AI returned an unexpected response. Please try again.';
      default:
        return fallback.isEmpty
            ? 'AI analysis could not be completed. Please try again.'
            : fallback;
    }
  }

  Future<InspectionModel> _scanLabelBackend({
    required List<ProductImage> productImages,
    required bool useSampleAsset,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.scanEndpoint),
      );
      for (final img in productImages) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            img.bytes,
            filename: img.filename,
          ),
        );
      }

      final streamed = await request.send().timeout(
            const Duration(seconds: 90),
          );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw ApiException(
            'AI analysis could not be completed. Please try again.',
          );
        }
        return InspectionModel.fromApi(
          decoded,
          productImages: productImages,
          useSampleAsset: useSampleAsset,
        );
      }

      final detail = _extractDetail(response.body);
      if (response.statusCode == 400 && detail.isNotEmpty) {
        throw ApiException(detail);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw ApiException(
          detail.isNotEmpty
              ? detail
              : 'AI analysis could not be completed. Please try again.',
        );
      }
      if (response.statusCode == 429) {
        throw ApiException(
          'The analysis service is busy. Please try again shortly.',
        );
      }
      if (response.statusCode >= 500) {
        throw ApiException(
          'Unable to connect to the inspection service. Please try again.',
          backendUnavailable: true,
        );
      }
      throw ApiException(
        detail.isNotEmpty
            ? detail
            : 'AI analysis could not be completed. Please try again.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Unable to connect to the inspection service. Please try again.',
        backendUnavailable: true,
      );
    }
  }

  String _extractDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {
    }
    return '';
  }

  Future<String> saveInspection(InspectionModel model) async {
    try {
      final payload = model.toJsonForBackend();
      final response = await http
          .post(
            Uri.parse(AppConfig.saveInspectionEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['report_id'] is String) {
          return decoded['report_id'] as String;
        }
        return model.reportId;
      }
      throw ApiException(
        'Backend refused save: HTTP ${response.statusCode}',
        backendUnavailable: response.statusCode >= 500,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Unable to save report to backend. $e',
        backendUnavailable: true,
      );
    }
  }

  Future<List<RecentReport>> listInspections({int limit = 50}) async {
    try {
      final response = await http
          .get(Uri.parse(AppConfig.listInspectionsEndpoint(limit: limit)))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Backend refused list: HTTP ${response.statusCode}',
          backendUnavailable: response.statusCode >= 500,
        );
      }
      final decoded = jsonDecode(response.body);
      final items = decoded is Map && decoded['items'] is List
          ? decoded['items'] as List
          : const [];
      return items.whereType<Map>().map((raw) {
        final r = Map<String, dynamic>.from(raw);
        final overall =
            (r['overall_status'] as String? ?? '').toUpperCase();
        ComplianceStatus s;
        if (overall.contains('NON_COMPLIANT') || overall == 'FAIL') {
          s = ComplianceStatus.fail;
        } else if (overall.contains('MANUAL') || overall == 'REVIEW') {
          s = ComplianceStatus.review;
        } else {
          s = ComplianceStatus.pass;
        }
        final dtStr = r['inspection_date'] as String?;
        final dt =
            dtStr != null ? DateTime.tryParse(dtStr) ?? DateTime.now() : DateTime.now();
        return RecentReport(
          id: (r['report_id'] as String?) ?? 'row-?',
          productName:
              (r['product_name'] as String?) ?? '(unnamed product)',
          status: s,
          date: dt,
        );
      }).toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Unable to load history from backend. $e',
        backendUnavailable: true,
      );
    }
  }

  Future<InspectionModel> getInspection(String reportId) async {
    try {
      final response = await http
          .get(Uri.parse(AppConfig.getInspectionEndpoint(reportId)))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) {
        throw ApiException('Inspection not found on backend.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Backend refused fetch: HTTP ${response.statusCode}',
          backendUnavailable: response.statusCode >= 500,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw ApiException('Invalid backend response for inspection.');
      }
      return InspectionModel.fromBackendJson(decoded);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Unable to load report from backend. $e',
        backendUnavailable: true,
      );
    }
  }
}
