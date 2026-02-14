import 'package:pos_app/models/menu_item.dart';

enum SortOption {
  relevance,
  priceLowHigh,
  priceHighLow,
  ratingHighest,
  prepTimeFastest,
}

extension SortOptionLabel on SortOption {
  String get label {
    switch (this) {
      case SortOption.relevance:       return 'Relevance';
      case SortOption.priceLowHigh:    return 'Price: Low → High';
      case SortOption.priceHighLow:    return 'Price: High → Low';
      case SortOption.ratingHighest:   return 'Highest Rated';
      case SortOption.prepTimeFastest: return 'Fastest First';
    }
  }

  String get icon {
    switch (this) {
      case SortOption.relevance:       return '✦';
      case SortOption.priceLowHigh:    return '↑';
      case SortOption.priceHighLow:    return '↓';
      case SortOption.ratingHighest:   return '★';
      case SortOption.prepTimeFastest: return '⚡';
    }
  }
}

class MenuFilterModel {
  // Diet
  final bool vegOnly;
  final bool nonVegOnly;

  // Availability
  final bool availableOnly;
  final bool bestsellersOnly;

  // Price range
  final double minPrice;
  final double maxPrice;

  // Rating
  final double minRating;

  // Prep time (max minutes)
  final int maxPrepTime;

  // Ingredients to include (item must contain ALL selected)
  final Set<String> includeIngredients;

  // Allergens to exclude (item must NOT contain any selected)
  final Set<String> excludeAllergens;

  // Sort
  final SortOption sortBy;

  const MenuFilterModel({
    this.vegOnly = false,
    this.nonVegOnly = false,
    this.availableOnly = false,
    this.bestsellersOnly = false,
    this.minPrice = 0,
    this.maxPrice = 500,
    this.minRating = 0,
    this.maxPrepTime = 60,
    this.includeIngredients = const {},
    this.excludeAllergens = const {},
    this.sortBy = SortOption.relevance,
  });

  MenuFilterModel copyWith({
    bool? vegOnly,
    bool? nonVegOnly,
    bool? availableOnly,
    bool? bestsellersOnly,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    int? maxPrepTime,
    Set<String>? includeIngredients,
    Set<String>? excludeAllergens,
    SortOption? sortBy,
  }) {
    return MenuFilterModel(
      vegOnly: vegOnly ?? this.vegOnly,
      nonVegOnly: nonVegOnly ?? this.nonVegOnly,
      availableOnly: availableOnly ?? this.availableOnly,
      bestsellersOnly: bestsellersOnly ?? this.bestsellersOnly,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minRating: minRating ?? this.minRating,
      maxPrepTime: maxPrepTime ?? this.maxPrepTime,
      includeIngredients: includeIngredients ?? this.includeIngredients,
      excludeAllergens: excludeAllergens ?? this.excludeAllergens,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  bool get isDefault =>
      !vegOnly &&
      !nonVegOnly &&
      !availableOnly &&
      !bestsellersOnly &&
      minPrice == 0 &&
      maxPrice == 500 &&
      minRating == 0 &&
      maxPrepTime == 60 &&
      includeIngredients.isEmpty &&
      excludeAllergens.isEmpty &&
      sortBy == SortOption.relevance;

  int get activeCount {
    int count = 0;
    if (vegOnly || nonVegOnly) count++;
    if (availableOnly) count++;
    if (bestsellersOnly) count++;
    if (minPrice > 0 || maxPrice < 500) count++;
    if (minRating > 0) count++;
    if (maxPrepTime < 60) count++;
    if (includeIngredients.isNotEmpty) count++;
    if (excludeAllergens.isNotEmpty) count++;
    if (sortBy != SortOption.relevance) count++;
    return count;
  }

  /// Apply filter + sort to a list of items
  List<MenuItem> apply(List<MenuItem> items) {
    var result = items.where((item) {
      if (vegOnly && !item.isVeg) return false;
      if (nonVegOnly && item.isVeg) return false;
      if (availableOnly && !item.available) return false;
      if (bestsellersOnly && !item.isBestseller) return false;
      if (item.price < minPrice || item.price > maxPrice) return false;
      if (item.rating < minRating) return false;
      if (item.prepTimeMinutes > maxPrepTime) return false;
      if (includeIngredients.isNotEmpty) {
        final itemIngs = item.ingredients.map((e) => e.toLowerCase()).toSet();
        for (final ing in includeIngredients) {
          if (!itemIngs.any((i) => i.contains(ing.toLowerCase()))) return false;
        }
      }
      if (excludeAllergens.isNotEmpty) {
        final itemAllergens =
            item.allergens.map((e) => e.toLowerCase()).toSet();
        for (final allergen in excludeAllergens) {
          if (itemAllergens.contains(allergen.toLowerCase())) return false;
        }
      }
      return true;
    }).toList();

    switch (sortBy) {
      case SortOption.priceLowHigh:
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceHighLow:
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.ratingHighest:
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SortOption.prepTimeFastest:
        result.sort((a, b) => a.prepTimeMinutes.compareTo(b.prepTimeMinutes));
        break;
      case SortOption.relevance:
        break;
    }
    return result;
  }

  static const MenuFilterModel defaults = MenuFilterModel();
}