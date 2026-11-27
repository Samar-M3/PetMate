/// Maps PetMate animal types to Google ML Kit Image Labeling labels.
///
/// Labels are matched case-insensitively. Keep this mapping centralized so
/// new animal types or synonym refinements can be added in one place.
class AnimalLabelMapper {
  const AnimalLabelMapper._();

  /// Recognized ML Kit labels (lowercased) for each supported PetMate animal type.
  ///
  /// Note: Generic labels such as "pet", "animal", or "mammal" are intentionally
  /// excluded so that a cat photo is never accepted when Dog is selected.
  static const Map<String, Set<String>> _animalLabels = {
    'Dog': {
      'dog',
      'puppy',
      'canine',
      'hound',
      'terrier',
      'retriever',
      'shepherd dog',
      'bulldog',
      'poodle',
      'pug',
      'husky',
      'beagle',
      'working dog',
      'companion dog',
      'sporting group',
    },
    'Cat': {
      'cat',
      'kitten',
      'feline',
      'tabby',
      'persian cat',
      'siamese cat',
      'domestic short-haired cat',
      'domestic long-haired cat',
    },
    'Rabbit': {
      'rabbit',
      'bunny',
      'hare',
      'cottontail',
      'domestic rabbit',
    },
    'Bird': {
      'bird',
      'parrot',
      'parakeet',
      'cockatiel',
      'canary',
      'finch',
      'budgerigar',
      'lovebird',
      'macaw',
      'owl',
      'pigeon',
      'dove',
      'duck',
      'songbird',
      'beak',
    },
    'Hamster': {
      'hamster',
      'gerbil',
    },
    'Guinea Pig': {
      'guinea pig',
      'cavy',
    },
    'Turtle': {
      'turtle',
      'tortoise',
      'terrapin',
      'sea turtle',
      'box turtle',
    },
  };

  /// Returns `true` if [animalType] has explicit label mappings supported
  /// for on-device ML Kit validation.
  static bool isSupportedAnimalType(String animalType) {
    return _findCanonicalKey(animalType) != null;
  }

  /// Returns the canonical animal type key if [animalType] is supported,
  /// or `null` if it is unsupported (e.g. "Other").
  static String? canonicalAnimalType(String animalType) {
    return _findCanonicalKey(animalType);
  }

  /// Returns the set of lowercased ML Kit labels associated with [animalType],
  /// or an empty set if [animalType] is not supported.
  static Set<String> labelsFor(String animalType) {
    final key = _findCanonicalKey(animalType);
    if (key == null) return const {};
    return _animalLabels[key] ?? const {};
  }

  /// Checks whether [mlKitLabel] matches the expected [animalType].
  static bool matchesAnimal(String mlKitLabel, String animalType) {
    final normalizedLabel = mlKitLabel.trim().toLowerCase();
    if (normalizedLabel.isEmpty) return false;
    return labelsFor(animalType).contains(normalizedLabel);
  }

  /// Finds which supported PetMate animal type (if any) [mlKitLabel] belongs to.
  static String? detectAnimalTypeFromLabel(String mlKitLabel) {
    final normalizedLabel = mlKitLabel.trim().toLowerCase();
    if (normalizedLabel.isEmpty) return null;
    for (final entry in _animalLabels.entries) {
      if (entry.value.contains(normalizedLabel)) {
        return entry.key;
      }
    }
    return null;
  }

  static String? _findCanonicalKey(String animalType) {
    final normalized = animalType.trim().toLowerCase();
    for (final key in _animalLabels.keys) {
      if (key.toLowerCase() == normalized) {
        return key;
      }
    }
    return null;
  }
}
