class MenuItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final String subcategory;
  final bool available;
  final String description;
  final List<String> ingredients;
  final List<String> allergens;
  final String? imageUrl;
  final double rating;
  final int prepTimeMinutes;
  final bool isVeg;
  final bool isBestseller;
  final NutritionalInfo? nutrition;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.subcategory,
    required this.available,
    this.description = '',
    this.ingredients = const [],
    this.allergens = const [],
    this.imageUrl,
    this.rating = 4.0,
    this.prepTimeMinutes = 15,
    this.isVeg = true,
    this.isBestseller = false,
    this.nutrition,
  });

  MenuItem copyWith({bool? available}) {
    return MenuItem(
      id: id,
      name: name,
      price: price,
      category: category,
      subcategory: subcategory,
      available: available ?? this.available,
      description: description,
      ingredients: ingredients,
      allergens: allergens,
      imageUrl: imageUrl,
      rating: rating,
      prepTimeMinutes: prepTimeMinutes,
      isVeg: isVeg,
      isBestseller: isBestseller,
      nutrition: nutrition,
    );
  }
}

class NutritionalInfo {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  NutritionalInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}