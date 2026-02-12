class MenuItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final String image;
  final double rating;
  final int reviews;
  final String description;
  final bool isVeg;

  MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.image,
    required this.rating,
    required this.reviews,
    required this.description,
    required this.isVeg,
  });
}

class CartItem {
  final MenuItem menuItem;
  int quantity;

  CartItem({required this.menuItem, this.quantity = 1});

  double get totalPrice => menuItem.price * quantity;
}
