class MenuCategory {
  final String name;
  final String icon;
  final int itemCount;
  final String? imageUrl;
  final List<String> subcategories;

  MenuCategory({
    required this.name,
    required this.icon,
    required this.itemCount,
    this.imageUrl,
    this.subcategories = const [],
  });
}