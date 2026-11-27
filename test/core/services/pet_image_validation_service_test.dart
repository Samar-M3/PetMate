import 'package:flutter_test/flutter_test.dart';
import 'package:petmatee/core/services/animal_label_mapper.dart';
import 'package:petmatee/core/services/pet_image_validation_service.dart';

void main() {
  group('AnimalLabelMapper', () {
    test('supports expected pet animal types case-insensitively', () {
      expect(AnimalLabelMapper.isSupportedAnimalType('Dog'), isTrue);
      expect(AnimalLabelMapper.isSupportedAnimalType('dog'), isTrue);
      expect(AnimalLabelMapper.isSupportedAnimalType('Cat'), isTrue);
      expect(AnimalLabelMapper.isSupportedAnimalType('Rabbit'), isTrue);
      expect(AnimalLabelMapper.isSupportedAnimalType('Bird'), isTrue);
      expect(AnimalLabelMapper.isSupportedAnimalType('Hamster'), isTrue);
      expect(AnimalLabelMapper.isSupportedAnimalType('Guinea Pig'), isTrue);
      expect(AnimalLabelMapper.isSupportedAnimalType('Turtle'), isTrue);
      expect(AnimalLabelMapper.isSupportedAnimalType('Other'), isFalse);
    });

    test('matches synonyms accurately without accepting generic animal labels', () {
      expect(AnimalLabelMapper.matchesAnimal('Puppy', 'Dog'), isTrue);
      expect(AnimalLabelMapper.matchesAnimal('Kitten', 'Cat'), isTrue);
      expect(AnimalLabelMapper.matchesAnimal('Bunny', 'Rabbit'), isTrue);
      expect(AnimalLabelMapper.matchesAnimal('Parrot', 'Bird'), isTrue);
      expect(AnimalLabelMapper.matchesAnimal('Tortoise', 'Turtle'), isTrue);

      // Generic labels must not match specific animal types
      expect(AnimalLabelMapper.matchesAnimal('Pet', 'Dog'), isFalse);
      expect(AnimalLabelMapper.matchesAnimal('Animal', 'Dog'), isFalse);
      expect(AnimalLabelMapper.matchesAnimal('Mammal', 'Cat'), isFalse);
    });
  });

  group('PetImageValidationService.evaluateLabels', () {
    late PetImageValidationService service;

    setUp(() {
      service = PetImageValidationService(confidenceThreshold: 0.65);
    });

    tearDown(() async {
      await service.dispose();
    });

    test('accepts Dog selected with dog photo above threshold', () {
      final result = service.evaluateLabels(
        labels: const [
          DetectedLabelInfo(label: 'Dog', confidence: 0.92),
          DetectedLabelInfo(label: 'Pet', confidence: 0.88),
        ],
        selectedAnimalType: 'Dog',
      );

      expect(result.isValid, isTrue);
      expect(result.status, PetImageValidationStatus.valid);
      expect(result.matchedConfidence, 0.92);
    });

    test('accepts Dog selected with Puppy synonym', () {
      final result = service.evaluateLabels(
        labels: const [
          DetectedLabelInfo(label: 'Puppy', confidence: 0.78),
        ],
        selectedAnimalType: 'Dog',
      );

      expect(result.isValid, isTrue);
      expect(result.status, PetImageValidationStatus.valid);
    });

    test('rejects Dog selected with cat photo', () {
      final result = service.evaluateLabels(
        labels: const [
          DetectedLabelInfo(label: 'Cat', confidence: 0.91),
          DetectedLabelInfo(label: 'Mammal', confidence: 0.85),
        ],
        selectedAnimalType: 'Dog',
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.mismatch);
      expect(result.detectedOtherAnimal, 'Cat');
      expect(result.message, contains('Dog'));
      expect(result.message, contains('cat'));
    });

    test('rejects Cat selected with dog photo', () {
      final result = service.evaluateLabels(
        labels: const [
          DetectedLabelInfo(label: 'Dog', confidence: 0.87),
        ],
        selectedAnimalType: 'Cat',
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.mismatch);
      expect(result.detectedOtherAnimal, 'Dog');
    });

    test('accepts Rabbit selected with rabbit photo', () {
      final result = service.evaluateLabels(
        labels: const [
          DetectedLabelInfo(label: 'Rabbit', confidence: 0.84),
        ],
        selectedAnimalType: 'Rabbit',
      );

      expect(result.isValid, isTrue);
      expect(result.status, PetImageValidationStatus.valid);
    });

    test('rejects Bird selected with dog photo', () {
      final result = service.evaluateLabels(
        labels: const [
          DetectedLabelInfo(label: 'Dog', confidence: 0.89),
        ],
        selectedAnimalType: 'Bird',
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.mismatch);
      expect(result.detectedOtherAnimal, 'Dog');
    });

    test('rejects random non-animal image', () {
      final result = service.evaluateLabels(
        labels: const [
          DetectedLabelInfo(label: 'Chair', confidence: 0.90),
          DetectedLabelInfo(label: 'Furniture', confidence: 0.82),
        ],
        selectedAnimalType: 'Cat',
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.mismatch);
    });

    test('rejects blurry or low-confidence pet image below threshold', () {
      final result = service.evaluateLabels(
        labels: const [
          DetectedLabelInfo(label: 'Dog', confidence: 0.52),
        ],
        selectedAnimalType: 'Dog',
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.blurryOrLowConfidence);
    });

    test('rejects image containing multiple distinct animals', () {
      final result = service.evaluateLabels(
        labels: const [
          DetectedLabelInfo(label: 'Dog', confidence: 0.86),
          DetectedLabelInfo(label: 'Cat', confidence: 0.81),
        ],
        selectedAnimalType: 'Dog',
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.multipleAnimals);
    });

    test('rejects when no labels are returned', () {
      final result = service.evaluateLabels(
        labels: const [],
        selectedAnimalType: 'Dog',
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.noLabels);
    });

    test('handles unsupported animal type explicitly', () {
      final result = service.evaluateLabels(
        labels: const [
          DetectedLabelInfo(label: 'Dog', confidence: 0.90),
        ],
        selectedAnimalType: 'Other',
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.unsupportedAnimal);
    });

    test('respects custom configurable confidence threshold', () {
      final strictService = PetImageValidationService(confidenceThreshold: 0.85);
      final result = strictService.evaluateLabels(
        labels: const [
          DetectedLabelInfo(label: 'Dog', confidence: 0.75),
        ],
        selectedAnimalType: 'Dog',
      );

      expect(result.isValid, isFalse);
      expect(result.status, PetImageValidationStatus.blurryOrLowConfidence);
    });
  });
}
