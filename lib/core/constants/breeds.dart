class PetSpeciesConstants {
  static const List<Map<String, String>> speciesOptions = [
    {'value': 'DOG', 'label': 'Dog'},
    {'value': 'CAT', 'label': 'Cat'},
    {'value': 'BIRD', 'label': 'Bird'},
    {'value': 'RABBIT', 'label': 'Rabbit'},
    {'value': 'HAMSTER', 'label': 'Hamster'},
    {'value': 'OTHER', 'label': 'Other'},
  ];

  static const Map<String, List<String>> breedsBySpecies = {
    'DOG': [
      'Labrador Retriever',
      'German Shepherd',
      'Golden Retriever',
      'Beagle',
      'Pug',
      'Rottweiler',
      'Shih Tzu',
      'Siberian Husky',
      'Doberman',
      'Lhasa Apso',
      'Boxer',
      'Cocker Spaniel',
      'Mixed',
      'Other',
    ],
    'CAT': [
      'Persian',
      'Siamese',
      'Maine Coon',
      'Bengal',
      'British Shorthair',
      'Ragdoll',
      'Domestic Shorthair',
      'Mixed',
      'Other',
    ],
    'BIRD': [
      'Budgerigar',
      'Cockatiel',
      'Lovebird',
      'Parrot',
      'Pigeon',
      'Other',
    ],
    'RABBIT': [
      'Holland Lop',
      'Netherland Dwarf',
      'Mini Rex',
      'Lionhead',
      'Mixed',
      'Other',
    ],
    'HAMSTER': [
      'Syrian',
      "Campbell's Dwarf",
      'Roborovski',
      'Winter White',
      'Chinese',
      'Other',
    ],
  };

  static List<String> get allSpecies =>
      speciesOptions.map((e) => e['label']!).toList();

  static List<String> breedsFor(String species) {
    return breedsBySpecies[species.toUpperCase()] ?? const [];
  }

  static List<String> breedsForSpecies(String species) => breedsFor(species);

  static String labelFor(String species) {
    for (final item in speciesOptions) {
      if (item['value'] == species.toUpperCase()) {
        return item['label']!;
      }
    }
    return 'Other';
  }
}
