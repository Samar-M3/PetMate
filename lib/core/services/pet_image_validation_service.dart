import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import 'animal_label_mapper.dart';

/// Default minimum confidence required to accept a pet image.
const double kDefaultPetValidationConfidenceThreshold = 0.65;

final petImageValidationServiceProvider =
    Provider<PetImageValidationService>((ref) {
  final service = PetImageValidationService();
  ref.onDispose(service.dispose);
  return service;
});

enum PetImageValidationStatus {
  valid,
  mismatch,
  multipleAnimals,
  noLabels,
  blurryOrLowConfidence,
  unsupportedAnimal,
  processingError,
}

class DetectedLabelInfo {
  final String label;
  final double confidence;

  const DetectedLabelInfo({
    required this.label,
    required this.confidence,
  });

  @override
  String toString() => '$label (${(confidence * 100).toStringAsFixed(1)}%)';
}

class PetImageValidationResult {
  final bool isValid;
  final PetImageValidationStatus status;
  final String selectedAnimalType;
  final String message;
  final double? matchedConfidence;
  final String? detectedOtherAnimal;
  final List<DetectedLabelInfo> labels;

  const PetImageValidationResult({
    required this.isValid,
    required this.status,
    required this.selectedAnimalType,
    required this.message,
    this.matchedConfidence,
    this.detectedOtherAnimal,
    this.labels = const [],
  });
}

/// On-device pet image validation service powered by Google ML Kit Image Labeling.
class PetImageValidationService {
  final double confidenceThreshold;
  ImageLabeler? _labeler;
  bool _isDisposed = false;

  PetImageValidationService({
    this.confidenceThreshold = kDefaultPetValidationConfidenceThreshold,
  });

  ImageLabeler _getOrCreateLabeler() {
    // Use a slightly lower internal threshold (0.45) so we can distinguish
    // blurry/low-confidence detections from completely unrecognizable images,
    // while strictly enforcing `confidenceThreshold` (0.65) for acceptance.
    final internalThreshold =
        confidenceThreshold < 0.45 ? confidenceThreshold : 0.45;
    return _labeler ??= ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: internalThreshold),
    );
  }

  /// Validates an image at [imageFile] (or [imageBytes] on web) against [selectedAnimalType].
  Future<PetImageValidationResult> validatePetImage({
    required File? imageFile,
    Uint8List? imageBytes,
    required String selectedAnimalType,
  }) async {
    if (_isDisposed) {
      return PetImageValidationResult(
        isValid: false,
        status: PetImageValidationStatus.processingError,
        selectedAnimalType: selectedAnimalType,
        message: 'Image validation service is unavailable. Please try again.',
      );
    }

    if (!AnimalLabelMapper.isSupportedAnimalType(selectedAnimalType)) {
      return PetImageValidationResult(
        isValid: false,
        status: PetImageValidationStatus.unsupportedAnimal,
        selectedAnimalType: selectedAnimalType,
        message:
            'Automatic photo verification is not supported for "$selectedAnimalType". Please select a supported animal type (such as Dog, Cat, Rabbit, or Bird).',
      );
    }

    // Google ML Kit's on-device image labeler only runs on Android/iOS.
    // On Flutter Web (e.g. Chrome), verify the selected bytes are a valid image
    // so users can still upload pet photos during web testing/usage.
    if (kIsWeb) {
      if (imageBytes == null ||
          imageBytes.isEmpty ||
          !_hasValidImageHeader(imageBytes)) {
        return PetImageValidationResult(
          isValid: false,
          status: PetImageValidationStatus.processingError,
          selectedAnimalType: selectedAnimalType,
          message: 'Please select a valid image file (JPG, PNG, or WebP).',
        );
      }
      return PetImageValidationResult(
        isValid: true,
        status: PetImageValidationStatus.valid,
        selectedAnimalType: selectedAnimalType,
        message: 'Photo ready for upload (animal detection runs on mobile).',
      );
    }

    if (imageFile == null) {
      return PetImageValidationResult(
        isValid: false,
        status: PetImageValidationStatus.processingError,
        selectedAnimalType: selectedAnimalType,
        message:
            'We could not read the selected image file. Please choose another photo.',
      );
    }

    if (!await imageFile.exists()) {
      return PetImageValidationResult(
        isValid: false,
        status: PetImageValidationStatus.processingError,
        selectedAnimalType: selectedAnimalType,
        message:
            'We could not read the selected image file. Please choose another photo.',
      );
    }

    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final labeler = _getOrCreateLabeler();
      final rawLabels = await labeler.processImage(inputImage);

      final extracted = rawLabels
          .map(
            (l) => DetectedLabelInfo(
              label: l.label,
              confidence: l.confidence,
            ),
          )
          .toList();

      return evaluateLabels(
        labels: extracted,
        selectedAnimalType: selectedAnimalType,
      );
    } catch (_) {
      return PetImageValidationResult(
        isValid: false,
        status: PetImageValidationStatus.processingError,
        selectedAnimalType: selectedAnimalType,
        message:
            'We couldn\'t process this image. Please try another clear photo of your $selectedAnimalType.',
      );
    }
  }

  /// Pure evaluation of extracted ML Kit [labels] against [selectedAnimalType].
  ///
  /// Exposed for deterministic unit testing without requiring native ML Kit bindings.
  @visibleForTesting
  PetImageValidationResult evaluateLabels({
    required List<DetectedLabelInfo> labels,
    required String selectedAnimalType,
  }) {
    if (!AnimalLabelMapper.isSupportedAnimalType(selectedAnimalType)) {
      return PetImageValidationResult(
        isValid: false,
        status: PetImageValidationStatus.unsupportedAnimal,
        selectedAnimalType: selectedAnimalType,
        message:
            'Automatic photo verification is not supported for "$selectedAnimalType". Please select a supported animal type (such as Dog, Cat, Rabbit, or Bird).',
        labels: labels,
      );
    }

    if (labels.isEmpty) {
      return PetImageValidationResult(
        isValid: false,
        status: PetImageValidationStatus.noLabels,
        selectedAnimalType: selectedAnimalType,
        message:
            'We couldn\'t clearly identify the animal. Please upload a clearer photo.',
        labels: labels,
      );
    }

    final canonicalSelected =
        AnimalLabelMapper.canonicalAnimalType(selectedAnimalType) ??
            selectedAnimalType;

    double? highestSelectedConfidence;
    double? highestLowConfidenceMatch;
    final Map<String, double> detectedOtherAnimals = {};

    for (final item in labels) {
      if (AnimalLabelMapper.matchesAnimal(item.label, canonicalSelected)) {
        if (item.confidence >= confidenceThreshold) {
          if (highestSelectedConfidence == null ||
              item.confidence > highestSelectedConfidence) {
            highestSelectedConfidence = item.confidence;
          }
        } else {
          if (highestLowConfidenceMatch == null ||
              item.confidence > highestLowConfidenceMatch) {
            highestLowConfidenceMatch = item.confidence;
          }
        }
      } else {
        final otherType =
            AnimalLabelMapper.detectAnimalTypeFromLabel(item.label);
        if (otherType != null &&
            otherType != canonicalSelected &&
            item.confidence >= confidenceThreshold) {
          final existing = detectedOtherAnimals[otherType];
          if (existing == null || item.confidence > existing) {
            detectedOtherAnimals[otherType] = item.confidence;
          }
        }
      }
    }

    // Multiple distinct supported animals detected confidently
    if (highestSelectedConfidence != null && detectedOtherAnimals.isNotEmpty) {
      return PetImageValidationResult(
        isValid: false,
        status: PetImageValidationStatus.multipleAnimals,
        selectedAnimalType: selectedAnimalType,
        matchedConfidence: highestSelectedConfidence,
        detectedOtherAnimal: detectedOtherAnimals.keys.first,
        message:
            'Multiple animals were detected in this photo. Please upload a clear photo showing only your $selectedAnimalType.',
        labels: labels,
      );
    }

    // Selected animal confidently matched
    if (highestSelectedConfidence != null) {
      return PetImageValidationResult(
        isValid: true,
        status: PetImageValidationStatus.valid,
        selectedAnimalType: selectedAnimalType,
        matchedConfidence: highestSelectedConfidence,
        message: 'Photo verified as $selectedAnimalType.',
        labels: labels,
      );
    }

    // A different supported animal was detected instead
    if (detectedOtherAnimals.isNotEmpty) {
      final topOther = detectedOtherAnimals.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      return PetImageValidationResult(
        isValid: false,
        status: PetImageValidationStatus.mismatch,
        selectedAnimalType: selectedAnimalType,
        detectedOtherAnimal: topOther.key,
        message:
            'This image doesn\'t appear to match the selected animal type. Please upload a valid photo.',
        labels: labels,
      );
    }

    // Selected animal was only seen below confidence threshold (blurry / unclear)
    if (highestLowConfidenceMatch != null) {
      return PetImageValidationResult(
        isValid: false,
        status: PetImageValidationStatus.blurryOrLowConfidence,
        selectedAnimalType: selectedAnimalType,
        matchedConfidence: highestLowConfidenceMatch,
        message:
            'We couldn\'t clearly identify the animal. Please upload a clearer photo.',
        labels: labels,
      );
    }

    // Generic mismatch (e.g., person, random object, landscape)
    return PetImageValidationResult(
      isValid: false,
      status: PetImageValidationStatus.mismatch,
      selectedAnimalType: selectedAnimalType,
      message:
          'This image doesn\'t appear to match the selected animal type. Please upload a valid photo.',
      labels: labels,
    );
  }

  static bool _hasValidImageHeader(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return true;
    }
    // WebP: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _labeler?.close();
    _labeler = null;
  }
}
