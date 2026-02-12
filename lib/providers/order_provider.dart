import 'package:flutter/foundation.dart';
import '../models/menu_item.dart';

class OrderProvider with ChangeNotifier {
  final List<MenuItem> _menuItems = [
    MenuItem(
      id: '1',
      name: 'Double Cheese Margherita',
      category: 'Pizza',
      price: 268,
      image:
          'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400',
      rating: 4.5,
      reviews: 388,
      description:
          'Enjoy an abundance of rich cheese, Mozzarella loaded along with fresh vegetables',
      isVeg: true,
    ),
    MenuItem(
      id: '2',
      name: 'Classic Burger',
      category: 'Burgers',
      price: 199,
      image:
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400',
      rating: 4.2,
      reviews: 256,
      description:
          'Juicy beef patty with fresh lettuce, tomatoes, and special sauce',
      isVeg: false,
    ),
    MenuItem(
      id: '3',
      name: 'Pepperoni Pizza',
      category: 'Pizza',
      price: 299,
      image:
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400',
      rating: 4.7,
      reviews: 512,
      description:
          'Classic pepperoni pizza with extra cheese and Italian herbs',
      isVeg: false,
    ),
    MenuItem(
      id: '4',
      name: 'Coca Cola',
      category: 'Beverages',
      price: 50,
      image: 'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=400',
      rating: 4.0,
      reviews: 180,
      description: 'Chilled Coca Cola 330ml',
      isVeg: true,
    ),
    MenuItem(
      id: '5',
      name: 'Grilled Chicken',
      category: 'Chicken',
      price: 350,
      image:
          'https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=400',
      rating: 4.6,
      reviews: 420,
      description: 'Tender grilled chicken with herbs and spices',
      isVeg: false,
    ),
    MenuItem(
      id: '6',
      name: 'Veggie Supreme Pizza',
      category: 'Pizza',
      price: 280,
      image:
          'https://images.unsplash.com/photo-1571997478779-2adcbbe9ab2f?w=400',
      rating: 4.3,
      reviews: 310,
      description: 'Loaded with fresh vegetables and premium mozzarella',
      isVeg: true,
    ),
  ];

  final List<CartItem> _cartItems = [];
  String _selectedCategory = 'All';

  List<MenuItem> get menuItems {
    if (_selectedCategory == 'All') {
      return _menuItems;
    }
    return _menuItems
        .where((item) => item.category == _selectedCategory)
        .toList();
  }

  List<CartItem> get cartItems => _cartItems;
  String get selectedCategory => _selectedCategory;

  int get cartItemCount =>
      _cartItems.fold(0, (sum, item) => sum + item.quantity);

  double get cartTotal =>
      _cartItems.fold(0, (sum, item) => sum + item.totalPrice);

  List<String> get categories => [
    'All',
    'Pizza',
    'Beverages',
    'Burgers',
    'Chicken',
  ];

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void addToCart(MenuItem item) {
    final existingIndex = _cartItems.indexWhere(
      (cartItem) => cartItem.menuItem.id == item.id,
    );

    if (existingIndex != -1) {
      _cartItems[existingIndex].quantity++;
    } else {
      _cartItems.add(CartItem(menuItem: item));
    }
    notifyListeners();
  }

  void removeFromCart(MenuItem item) {
    final existingIndex = _cartItems.indexWhere(
      (cartItem) => cartItem.menuItem.id == item.id,
    );

    if (existingIndex != -1) {
      if (_cartItems[existingIndex].quantity > 1) {
        _cartItems[existingIndex].quantity--;
      } else {
        _cartItems.removeAt(existingIndex);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  int getItemQuantity(MenuItem item) {
    final cartItem = _cartItems.firstWhere(
      (cartItem) => cartItem.menuItem.id == item.id,
      orElse: () => CartItem(menuItem: item, quantity: 0),
    );
    return cartItem.quantity;
  }
}
