import 'package:flutter_test/flutter_test.dart';
import 'package:petmatee/core/services/pet_image_validation_service.dart';

void main() {
  late PetImageValidationService service;

  setUp(() {
    service = PetImageValidationService();
  });

  tearDown(() async {
    await service.dispose();
  });

  group('PetImageValidationService.evaluateLabels', () {
    test('accepts Dog image when Dog is selected with sufficient confidence', () {
      final result = service.evaluateLabels(
        selectedAnimalType: 'Dog',
        labels: const [
          DetectedLabelInfo(label: 'Dog', confidence: 0.92),
          DetectedLabelInfo(label: 'Mammal', confidence: 0.88),
        ],
      );

      expect(result.isValid, isTrue);
      expect(result.status, PetImageValidationStatus.valid);
    });

    test('rejects Cat image when Dog is selected', () {
      final result = service.evaluateLabels(
        selectedAnimalType: 'Dog',
        labels: const [
          DetectedLabelInfo(label: 'Cat', confidence: 0.91),
          DetectedLabelInfo(label: 'Kitten', confidence: 0.80),
        ],
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.mismatch);
      expect(result.detectedOtherAnimal, 'Cat');
      expect(
        result.message,
        "This image doesn't appear to match the selected animal type. Please upload a valid photo.",
      );
    });

    test('rejects Human image when Dog is selected', () {
      final result = service.evaluateLabels(
        selectedAnimalType: 'Dog',
        labels: const [
          DetectedLabelInfo(label: 'Person', confidence: 0.95),
          DetectedLabelInfo(label: 'Smile', confidence: 0.85),
        ],
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.mismatch);
    });

    test('rejects Car or Landscape image when Dog is selected', () {
      final result = service.evaluateLabels(
        selectedAnimalType: 'Dog',
        labels: const [
          DetectedLabelInfo(label: 'Car', confidence: 0.93),
          DetectedLabelInfo(label: 'Vehicle', confidence: 0.90),
        ],
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.mismatch);
    });

    test('accepts Cat image when Cat is selected (case-insensitive)', () {
      final result = service.evaluateLabels(
        selectedAnimalType: 'CAT',
        labels: const [
          DetectedLabelInfo(label: 'Tabby', confidence: 0.78),
          DetectedLabelInfo(label: 'Cat', confidence: 0.89),
        ],
      );

      expect(result.isValid, isTrue);
      expect(result.status, PetImageValidationStatus.valid);
    });

    test('rejects Dog image when Cat is selected', () {
      final result = service.evaluateLabels(
        selectedAnimalType: 'Cat',
        labels: const [
          DetectedLabelInfo(label: 'Puppy', confidence: 0.87),
        ],
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.mismatch);
      expect(result.detectedOtherAnimal, 'Dog');
    });

    test('rejects blurry/low-confidence image instead of accepting', () {
      final result = service.evaluateLabels(
        selectedAnimalType: 'Dog',
        labels: const [
          DetectedLabelInfo(label: 'Dog', confidence: 0.52),
        ],
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.blurryOrLowConfidence);
      expect(
        result.message,
        "We couldn't clearly identify the animal. Please upload a clearer photo.",
      );
    });

    test('rejects empty labels (unrecognizable / very blurry)', () {
      final result = service.evaluateLabels(
        selectedAnimalType: 'Dog',
        labels: const [],
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.noLabels);
      expect(
        result.message,
        "We couldn't clearly identify the animal. Please upload a clearer photo.",
      );
    });

    test('rejects generic Animal/Pet label without specific species match', () {
      final result = service.evaluateLabels(
        selectedAnimalType: 'Dog',
        labels: const [
          DetectedLabelInfo(label: 'Animal', confidence: 0.90),
          DetectedLabelInfo(label: 'Pet', confidence: 0.85),
        ],
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.mismatch);
    });

    test('rejects multiple distinct animals in one photo', () {
      final result = service.evaluateLabels(
        selectedAnimalType: 'Dog',
        labels: const [
          DetectedLabelInfo(label: 'Dog', confidence: 0.88),
          DetectedLabelInfo(label: 'Cat', confidence: 0.82),
        ],
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.multipleAnimals);
    });

    test('explicitly handles unsupported animal type', () {
      final result = service.evaluateLabels(
        selectedAnimalType: 'Other',
        labels: const [
          DetectedLabelInfo(label: 'Dog', confidence: 0.90),
        ],
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.unsupportedAnimal);
    });
  });
}
