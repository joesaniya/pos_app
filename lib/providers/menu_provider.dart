import 'package:flutter/material.dart';
import 'package:pos_app/models/menu_category.dart';
import 'package:pos_app/repositories/menu_repository.dart';
import '../models/menu_item.dart';
import 'package:pos_app/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MenuProvider extends ChangeNotifier {
  String _selectedCategory = 'All';
  String _selectedSubcategory = 'All';
  String _searchQuery = '';

  bool _isLoading = false;
  String? _error;
  String _businessId = '';
  String _userUid = '';
  String _userName = '';

  MenuProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Get user from Firebase
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        _userUid = fbUser.uid;
      }

      final userData = await StorageService.instance.getUserData();
      _businessId = userData['businessId'] ?? '';
      _userName = userData['name'] as String? ?? 'Staff';

      if (_businessId.isNotEmpty) {
        await fetchMenuItems();
        MenuRepository.instance.subscribeRealtime(
          _businessId,
          () => fetchMenuItems(),
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMenuItems() async {
    if (_businessId.isEmpty) return;
    try {
      final items = await MenuRepository.instance.fetchMenuItems(_businessId);
      if (items.isNotEmpty) {
        _menuItems.clear();
        _menuItems.addAll(items);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to fetch menu: $e';
    }
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  final List<MenuCategory> categories = [
    MenuCategory(
      name: 'Dosa',
      icon: '🫓',
      itemCount: 12,
      imageUrl:
          'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400',
      subcategories: ['All', 'Plain', 'Masala', 'Rava', 'Set', 'Special'],
    ),
    MenuCategory(
      name: 'Curry',
      icon: '🍛',
      itemCount: 15,
      imageUrl:
          'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400',
      subcategories: ['All', 'Veg', 'Chicken', 'Mutton', 'Seafood'],
    ),
    MenuCategory(
      name: 'Breakfast',
      icon: '🍳',
      itemCount: 8,
      imageUrl:
          'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?w=400',
      subcategories: ['All', 'Idli', 'Vada', 'Pongal', 'Upma'],
    ),
    MenuCategory(
      name: 'Lunch',
      icon: '🍱',
      itemCount: 20,
      imageUrl:
          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
      subcategories: ['All', 'Rice', 'Roti', 'Combo', 'Thali'],
    ),
    MenuCategory(
      name: 'Dinner',
      icon: '🌙',
      itemCount: 18,
      imageUrl:
          'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400',
      subcategories: ['All', 'Biryani', 'Noodles', 'Grill', 'Soup'],
    ),
    MenuCategory(
      name: 'Desserts',
      icon: '🧁',
      itemCount: 10,
      imageUrl:
          'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400',
      subcategories: ['All', 'Ice Cream', 'Halwa', 'Kheer', 'Cake'],
    ),
    MenuCategory(
      name: 'Beverages',
      icon: '🥤',
      itemCount: 12,
      imageUrl:
          'https://images.unsplash.com/photo-1544145945-f90425340c7e?w=400',
      subcategories: ['All', 'Hot', 'Cold', 'Juices', 'Lassi'],
    ),
  ];

  final List<MenuItem> _menuItems = [
    // DOSA - Plain
    MenuItem(
      id: 'd1',
      name: 'Plain Dosa',
      price: 60.00,
      category: 'Dosa',
      subcategory: 'Plain',
      available: true,
      description:
          'Classic crispy rice and lentil crepe served with coconut chutney and sambar',
      ingredients: [
        'Rice batter',
        'Urad dal',
        'Fenugreek seeds',
        'Salt',
        'Oil',
      ],
      allergens: ['Gluten-free'],
      rating: 4.5,
      prepTimeMinutes: 10,
      isVeg: true,
      isBestseller: true,
      nutrition: NutritionalInfo(
        calories: 168,
        protein: 4.0,
        carbs: 30.0,
        fat: 3.7,
      ),
    ),
    MenuItem(
      id: 'd2',
      name: 'Butter Dosa',
      price: 80.00,
      category: 'Dosa',
      subcategory: 'Plain',
      available: true,
      description:
          'Golden dosa with generous butter topping, served with chutney and sambar',
      ingredients: ['Rice batter', 'Urad dal', 'Butter', 'Salt'],
      allergens: ['Dairy'],
      rating: 4.7,
      prepTimeMinutes: 10,
      isVeg: true,
      nutrition: NutritionalInfo(
        calories: 220,
        protein: 4.5,
        carbs: 30.0,
        fat: 9.0,
      ),
    ),
    // DOSA - Masala
    MenuItem(
      id: 'd3',
      name: 'Masala Dosa',
      price: 100.00,
      category: 'Dosa',
      subcategory: 'Masala',
      available: true,
      description:
          'Crispy dosa stuffed with spiced potato filling, served with chutneys and sambar',
      ingredients: [
        'Rice batter',
        'Potato',
        'Onion',
        'Mustard seeds',
        'Turmeric',
        'Green chilli',
        'Curry leaves',
      ],
      allergens: [],
      rating: 4.8,
      prepTimeMinutes: 15,
      isVeg: true,
      isBestseller: true,
      nutrition: NutritionalInfo(
        calories: 290,
        protein: 6.0,
        carbs: 52.0,
        fat: 7.0,
      ),
    ),
    MenuItem(
      id: 'd4',
      name: 'Onion Masala Dosa',
      price: 120.00,
      category: 'Dosa',
      subcategory: 'Masala',
      available: true,
      description: 'Masala dosa topped with crispy sautéed onions and spices',
      ingredients: [
        'Rice batter',
        'Potato',
        'Onion',
        'Red chilli',
        'Coriander',
        'Oil',
      ],
      allergens: [],
      rating: 4.6,
      prepTimeMinutes: 15,
      isVeg: true,
      nutrition: NutritionalInfo(
        calories: 310,
        protein: 6.5,
        carbs: 54.0,
        fat: 8.0,
      ),
    ),
    // DOSA - Rava
    MenuItem(
      id: 'd5',
      name: 'Rava Dosa',
      price: 90.00,
      category: 'Dosa',
      subcategory: 'Rava',
      available: true,
      description:
          'Crispy semolina dosa with jeera, pepper and coriander, extra thin and lacy',
      ingredients: [
        'Semolina',
        'Rice flour',
        'All-purpose flour',
        'Cumin',
        'Black pepper',
        'Ginger',
        'Green chilli',
      ],
      allergens: ['Gluten'],
      rating: 4.7,
      prepTimeMinutes: 12,
      isVeg: true,
      isBestseller: false,
      nutrition: NutritionalInfo(
        calories: 198,
        protein: 5.0,
        carbs: 34.0,
        fat: 4.5,
      ),
    ),
    MenuItem(
      id: 'd6',
      name: 'Rava Masala Dosa',
      price: 110.00,
      category: 'Dosa',
      subcategory: 'Rava',
      available: false,
      description: 'Lacy semolina dosa filled with spiced potato masala',
      ingredients: ['Semolina', 'Rice flour', 'Potato filling', 'Spices'],
      allergens: ['Gluten'],
      rating: 4.5,
      prepTimeMinutes: 18,
      isVeg: true,
      nutrition: NutritionalInfo(
        calories: 320,
        protein: 7.0,
        carbs: 55.0,
        fat: 8.5,
      ),
    ),
    // DOSA - Set
    MenuItem(
      id: 'd7',
      name: 'Set Dosa',
      price: 80.00,
      category: 'Dosa',
      subcategory: 'Set',
      available: true,
      description:
          'Soft, spongy trio of small dosas served with veg kurma and coconut chutney',
      ingredients: ['Rice batter', 'Urad dal', 'Poha', 'Fenugreek', 'Salt'],
      allergens: [],
      rating: 4.4,
      prepTimeMinutes: 15,
      isVeg: true,
      nutrition: NutritionalInfo(
        calories: 260,
        protein: 7.0,
        carbs: 46.0,
        fat: 5.0,
      ),
    ),
    // DOSA - Special
    MenuItem(
      id: 'd8',
      name: 'Ghee Roast Dosa',
      price: 140.00,
      category: 'Dosa',
      subcategory: 'Special',
      available: true,
      description:
          'Signature paper-thin dosa roasted in pure ghee until golden and crispy',
      ingredients: ['Rice batter', 'Pure ghee', 'Salt', 'Curry leaves'],
      allergens: ['Dairy'],
      rating: 4.9,
      prepTimeMinutes: 12,
      isVeg: true,
      isBestseller: true,
      nutrition: NutritionalInfo(
        calories: 280,
        protein: 5.0,
        carbs: 30.0,
        fat: 15.0,
      ),
    ),
    MenuItem(
      id: 'd9',
      name: 'Cheese Dosa',
      price: 150.00,
      category: 'Dosa',
      subcategory: 'Special',
      available: true,
      description:
          'Crispy dosa filled with melted cheese and seasoned with herbs',
      ingredients: [
        'Rice batter',
        'Cheddar cheese',
        'Mozzarella',
        'Herbs',
        'Butter',
      ],
      allergens: ['Dairy'],
      rating: 4.6,
      prepTimeMinutes: 15,
      isVeg: true,
      nutrition: NutritionalInfo(
        calories: 380,
        protein: 14.0,
        carbs: 32.0,
        fat: 22.0,
      ),
    ),
    // CURRY - Veg
    MenuItem(
      id: 'c1',
      name: 'Palak Paneer',
      price: 180.00,
      category: 'Curry',
      subcategory: 'Veg',
      available: true,
      description:
          'Fresh cottage cheese cubes in creamy spinach gravy with aromatic spices',
      ingredients: [
        'Spinach',
        'Paneer',
        'Cream',
        'Garlic',
        'Ginger',
        'Garam masala',
        'Cumin',
      ],
      allergens: ['Dairy'],
      rating: 4.7,
      prepTimeMinutes: 20,
      isVeg: true,
      isBestseller: true,
      nutrition: NutritionalInfo(
        calories: 340,
        protein: 18.0,
        carbs: 14.0,
        fat: 24.0,
      ),
    ),
    MenuItem(
      id: 'c2',
      name: 'Dal Makhani',
      price: 160.00,
      category: 'Curry',
      subcategory: 'Veg',
      available: true,
      description:
          'Slow-cooked black lentils in rich buttery tomato sauce, finished with cream',
      ingredients: [
        'Black urad dal',
        'Kidney beans',
        'Butter',
        'Cream',
        'Tomatoes',
        'Spices',
      ],
      allergens: ['Dairy'],
      rating: 4.8,
      prepTimeMinutes: 25,
      isVeg: true,
      nutrition: NutritionalInfo(
        calories: 310,
        protein: 15.0,
        carbs: 38.0,
        fat: 12.0,
      ),
    ),
    // CURRY - Chicken
    MenuItem(
      id: 'c3',
      name: 'Chicken Chettinad',
      price: 250.00,
      category: 'Curry',
      subcategory: 'Chicken',
      available: true,
      description:
          'Bold, aromatic Chettinad-style chicken curry with freshly ground masala',
      ingredients: [
        'Chicken',
        'Kalpasi',
        'Marathi mokku',
        'Kandan thippili',
        'Coconut',
        'Red chilli',
      ],
      allergens: [],
      rating: 4.9,
      prepTimeMinutes: 30,
      isVeg: false,
      isBestseller: true,
      nutrition: NutritionalInfo(
        calories: 420,
        protein: 35.0,
        carbs: 12.0,
        fat: 26.0,
      ),
    ),
    MenuItem(
      id: 'c4',
      name: 'Butter Chicken',
      price: 280.00,
      category: 'Curry',
      subcategory: 'Chicken',
      available: true,
      description:
          'Tender chicken in velvety tomato-butter sauce with mild aromatic spices',
      ingredients: [
        'Chicken',
        'Butter',
        'Cream',
        'Tomato puree',
        'Cashew paste',
        'Spices',
      ],
      allergens: ['Dairy', 'Nuts'],
      rating: 4.8,
      prepTimeMinutes: 25,
      isVeg: false,
      isBestseller: true,
      nutrition: NutritionalInfo(
        calories: 480,
        protein: 32.0,
        carbs: 18.0,
        fat: 32.0,
      ),
    ),
    // CURRY - Mutton
    MenuItem(
      id: 'c5',
      name: 'Mutton Kuzhambu',
      price: 320.00,
      category: 'Curry',
      subcategory: 'Mutton',
      available: true,
      description:
          'Traditional Tamil-style mutton curry slow-cooked in tamarind and spice base',
      ingredients: [
        'Mutton',
        'Tamarind',
        'Coconut',
        'Coriander seeds',
        'Red chilli',
        'Curry leaves',
      ],
      allergens: [],
      rating: 4.8,
      prepTimeMinutes: 45,
      isVeg: false,
      nutrition: NutritionalInfo(
        calories: 520,
        protein: 40.0,
        carbs: 10.0,
        fat: 36.0,
      ),
    ),
    // CURRY - Seafood
    MenuItem(
      id: 'c6',
      name: 'Prawn Masala',
      price: 350.00,
      category: 'Curry',
      subcategory: 'Seafood',
      available: false,
      description:
          'Juicy prawns in spiced coconut-tomato masala with coastal flavors',
      ingredients: [
        'Prawns',
        'Coconut milk',
        'Tomatoes',
        'Ginger-garlic paste',
        'Curry leaves',
        'Spices',
      ],
      allergens: ['Shellfish'],
      rating: 4.7,
      prepTimeMinutes: 25,
      isVeg: false,
      nutrition: NutritionalInfo(
        calories: 380,
        protein: 38.0,
        carbs: 8.0,
        fat: 22.0,
      ),
    ),
    // BREAKFAST
    MenuItem(
      id: 'b1',
      name: 'Idli Sambar',
      price: 60.00,
      category: 'Breakfast',
      subcategory: 'Idli',
      available: true,
      description:
          'Fluffy steamed rice cakes served with aromatic lentil soup and chutneys',
      ingredients: [
        'Rice batter',
        'Urad dal',
        'Fenugreek',
        'Toor dal',
        'Vegetables',
        'Tamarind',
      ],
      allergens: [],
      rating: 4.6,
      prepTimeMinutes: 20,
      isVeg: true,
      isBestseller: true,
      nutrition: NutritionalInfo(
        calories: 210,
        protein: 8.0,
        carbs: 40.0,
        fat: 2.5,
      ),
    ),
    MenuItem(
      id: 'b2',
      name: 'Medu Vada',
      price: 70.00,
      category: 'Breakfast',
      subcategory: 'Vada',
      available: true,
      description:
          'Crispy savory lentil donuts with cumin, pepper and curry leaves',
      ingredients: [
        'Urad dal',
        'Cumin',
        'Black pepper',
        'Green chilli',
        'Curry leaves',
        'Ginger',
      ],
      allergens: [],
      rating: 4.5,
      prepTimeMinutes: 15,
      isVeg: true,
      nutrition: NutritionalInfo(
        calories: 195,
        protein: 8.0,
        carbs: 28.0,
        fat: 6.5,
      ),
    ),
    MenuItem(
      id: 'b3',
      name: 'Ven Pongal',
      price: 80.00,
      category: 'Breakfast',
      subcategory: 'Pongal',
      available: true,
      description:
          'Comforting rice-lentil porridge with ghee, pepper, cumin and cashews',
      ingredients: [
        'Rice',
        'Moong dal',
        'Ghee',
        'Black pepper',
        'Cumin',
        'Cashews',
        'Curry leaves',
      ],
      allergens: ['Dairy', 'Nuts'],
      rating: 4.7,
      prepTimeMinutes: 25,
      isVeg: true,
      isBestseller: true,
      nutrition: NutritionalInfo(
        calories: 320,
        protein: 10.0,
        carbs: 52.0,
        fat: 10.0,
      ),
    ),
    MenuItem(
      id: 'b4',
      name: 'Rava Upma',
      price: 70.00,
      category: 'Breakfast',
      subcategory: 'Upma',
      available: true,
      description:
          'Savory semolina porridge with vegetables, mustard seeds and curry leaves',
      ingredients: [
        'Semolina',
        'Onion',
        'Tomato',
        'Peas',
        'Cashews',
        'Mustard',
        'Curry leaves',
      ],
      allergens: ['Gluten', 'Nuts'],
      rating: 4.3,
      prepTimeMinutes: 20,
      isVeg: true,
      nutrition: NutritionalInfo(
        calories: 265,
        protein: 7.0,
        carbs: 46.0,
        fat: 6.5,
      ),
    ),
    // BEVERAGES
    MenuItem(
      id: 'bv1',
      name: 'Filter Coffee',
      price: 50.00,
      category: 'Beverages',
      subcategory: 'Hot',
      available: true,
      description:
          'Traditional South Indian filter coffee with chicory, served in davara tumbler',
      ingredients: ['Coffee powder', 'Chicory', 'Full cream milk', 'Sugar'],
      allergens: ['Dairy'],
      rating: 4.9,
      prepTimeMinutes: 5,
      isVeg: true,
      isBestseller: true,
      nutrition: NutritionalInfo(
        calories: 85,
        protein: 3.5,
        carbs: 10.0,
        fat: 4.0,
      ),
    ),
    MenuItem(
      id: 'bv2',
      name: 'Mango Lassi',
      price: 90.00,
      category: 'Beverages',
      subcategory: 'Lassi',
      available: true,
      description:
          'Thick and creamy blended yogurt drink with Alphonso mango pulp',
      ingredients: ['Yogurt', 'Mango pulp', 'Sugar', 'Cardamom', 'Saffron'],
      allergens: ['Dairy'],
      rating: 4.8,
      prepTimeMinutes: 5,
      isVeg: true,
      isBestseller: true,
      nutrition: NutritionalInfo(
        calories: 220,
        protein: 6.0,
        carbs: 38.0,
        fat: 5.0,
      ),
    ),
    MenuItem(
      id: 'bv3',
      name: 'Masala Chai',
      price: 45.00,
      category: 'Beverages',
      subcategory: 'Hot',
      available: true,
      description:
          'Spiced milk tea with ginger, cardamom, cinnamon, cloves and black pepper',
      ingredients: [
        'Tea leaves',
        'Milk',
        'Ginger',
        'Cardamom',
        'Cinnamon',
        'Cloves',
      ],
      allergens: ['Dairy'],
      rating: 4.7,
      prepTimeMinutes: 7,
      isVeg: true,
      nutrition: NutritionalInfo(
        calories: 95,
        protein: 3.0,
        carbs: 14.0,
        fat: 3.5,
      ),
    ),
    MenuItem(
      id: 'bv4',
      name: 'Fresh Lime Soda',
      price: 60.00,
      category: 'Beverages',
      subcategory: 'Cold',
      available: true,
      description:
          'Refreshing carbonated lime drink, served sweet, salty or mixed',
      ingredients: ['Lime juice', 'Soda water', 'Salt', 'Sugar', 'Mint'],
      allergens: [],
      rating: 4.5,
      prepTimeMinutes: 3,
      isVeg: true,
      nutrition: NutritionalInfo(
        calories: 45,
        protein: 0.5,
        carbs: 11.0,
        fat: 0.0,
      ),
    ),
    // DESSERTS
    MenuItem(
      id: 'ds1',
      name: 'Gulab Jamun',
      price: 80.00,
      category: 'Desserts',
      subcategory: 'Halwa',
      available: true,
      description:
          'Soft milk-solid dumplings soaked in rose-cardamom sugar syrup, served warm',
      ingredients: [
        'Milk powder',
        'Flour',
        'Ghee',
        'Sugar syrup',
        'Rose water',
        'Cardamom',
        'Saffron',
      ],
      allergens: ['Dairy', 'Gluten'],
      rating: 4.8,
      prepTimeMinutes: 20,
      isVeg: true,
      isBestseller: true,
      nutrition: NutritionalInfo(
        calories: 290,
        protein: 5.0,
        carbs: 50.0,
        fat: 9.0,
      ),
    ),
    MenuItem(
      id: 'ds2',
      name: 'Ice Cream Sundae',
      price: 120.00,
      category: 'Desserts',
      subcategory: 'Ice Cream',
      available: true,
      description:
          'Three scoops with hot chocolate fudge, whipped cream and cherry on top',
      ingredients: [
        'Vanilla ice cream',
        'Chocolate sauce',
        'Whipped cream',
        'Cherry',
        'Wafer',
      ],
      allergens: ['Dairy', 'Gluten'],
      rating: 4.7,
      prepTimeMinutes: 5,
      isVeg: true,
      nutrition: NutritionalInfo(
        calories: 420,
        protein: 7.0,
        carbs: 58.0,
        fat: 18.0,
      ),
    ),
  ];

  String get selectedCategory => _selectedCategory;
  String get selectedSubcategory => _selectedSubcategory;
  String get searchQuery => _searchQuery;
  List<MenuItem> get allMenuItems => _menuItems;

  MenuCategory? get currentCategory {
    try {
      return categories.firstWhere((c) => c.name == _selectedCategory);
    } catch (_) {
      return null;
    }
  }

  List<MenuItem> get filteredItems {
    return _menuItems.where((item) {
      final matchCategory =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchSubcategory =
          _selectedSubcategory == 'All' ||
          item.subcategory == _selectedSubcategory;
      final matchSearch =
          _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCategory && matchSubcategory && matchSearch;
    }).toList();
  }

  List<MenuItem> itemsForCategory(
    String category, [
    String subcategory = 'All',
  ]) {
    return _menuItems.where((item) {
      final matchCat = item.category == category;
      final matchSub = subcategory == 'All' || item.subcategory == subcategory;
      return matchCat && matchSub;
    }).toList();
  }

  List<String> subcategoriesFor(String category) {
    try {
      final cat = categories.firstWhere((c) => c.name == category);
      return cat.subcategories;
    } catch (_) {
      return ['All'];
    }
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    _selectedSubcategory = 'All';
    notifyListeners();
  }

  void setSelectedSubcategory(String subcategory) {
    _selectedSubcategory = subcategory;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addMenuItem(MenuItem item) async {
    if (_businessId.isEmpty) return;
    try {
      await MenuRepository.instance.saveMenuItem(
        item,
        _businessId,
        isCreate: true,
      );
      _menuItems.add(item);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add item: $e';
      notifyListeners();
    }
  }

  Future<void> updateMenuItem(MenuItem item) async {
    if (_businessId.isEmpty) return;
    try {
      await MenuRepository.instance.saveMenuItem(
        item,
        _businessId,
        isCreate: false,
      );
      final index = _menuItems.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _menuItems[index] = item;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to update item: $e';
      notifyListeners();
    }
  }

  Future<void> deleteMenuItem(String itemId) async {
    if (_businessId.isEmpty) return;
    try {
      // Find the item to get categoryId
      final item = _menuItems.firstWhere(
        (i) => i.id == itemId,
        orElse: () => MenuItem(
          id: '',
          name: '',
          price: 0,
          category: 'Other',
          subcategory: '',
          available: true,
        ),
      );

      await MenuRepository.instance.deleteMenuItem(
        itemId: itemId,
        businessId: _businessId,
        categoryId: item.category.toLowerCase().replaceAll(' ', '_'),
        deletedByUid: _userUid,
        deletedByName: _userName,
      );
      _menuItems.removeWhere((i) => i.id == itemId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete item: $e';
      notifyListeners();
    }
  }

  void toggleItemAvailability(String itemId) async {
    final index = _menuItems.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      final updatedItem = _menuItems[index].copyWith(
        available: !_menuItems[index].available,
      );

      try {
        await MenuRepository.instance.saveMenuItem(
          updatedItem,
          _businessId,
          isCreate: false,
        );
        _menuItems[index] = updatedItem;
        notifyListeners();
      } catch (e) {
        _error = 'Failed to toggle availability: $e';
        notifyListeners();
      }
    }
  }
}
