import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AvishuApp());
}

//константы
const List<String> APP_CATEGORIES = ["РУБАШКИ", "ФУТБОЛКИ", "КОФТЫ", "КОСТЮМЫ", "БРЮКИ", "ШТАНЫ", "ПЛАТЬЯ", "ВЕРХНЯЯ ОДЕЖДА", "ЮБКИ", "АКСЕССУАРЫ"];
const List<String> APP_COLORS = ["БЕЛЫЙ", "ЧЕРНЫЙ", "КРАСНЫЙ", "СИНИЙ", "ЗЕЛЕНЫЙ", "СЕРЫЙ", "БЕЖЕВЫЙ", "МАДЖЕНТА", "КОРИЧНЕВЫЙ", "ЗОЛОТОЙ", "РОЗОВЫЙ", "ЛЁД", "ПУДРА", "МЕЛАНЖ", "АЙВОРИ", "КОФЕ"];
const List<String> APP_SIZES = ["XS", "S", "M", "L", "XL", "2XL", "3XL", "OVERSIZE"];

Widget buildProductImage(String? base64String, {double width = 100, double height = 100, BoxFit fit = BoxFit.cover}) {
  if (base64String == null || base64String.isEmpty) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
    );
  }

  try {
    return Image.memory(
      base64Decode(base64String),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, size: 20),
      ),
    );
  } catch (e) {
    return Container(
      width: width,
      height: height,
      color: Colors.red[50],
      child: const Icon(Icons.error_outline, size: 20, color: Colors.red),
    );
  }
}

int _parsePrice(String priceStr) {
  return int.tryParse(priceStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}

class Product {
  final String id;
  final String name;
  final String price;
  final bool isInStock;
  final String description;
  final String category;
  final List<String> colors;
  final List<String> sizes;
  final List<String> imageUrls; //в формате base64

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.isInStock,
    required this.description,
    required this.category,
    required this.colors,
    required this.sizes,
    required this.imageUrls,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    List<String> urls = [];
    if (data['imageUrls'] != null) {
      urls = List<String>.from(data['imageUrls']);
    } else if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
      urls = [data['imageUrl']];
    }
    
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      price: data['price'] ?? '',
      isInStock: data['isInStock'] ?? true,
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      colors: List<String>.from(data['colors'] ?? []),
      sizes: List<String>.from(data['sizes'] ?? []),
      imageUrls: urls,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'isInStock': isInStock,
    'description': description,
    'category': category,
    'colors': colors,
    'sizes': sizes,
    'imageUrls': imageUrls,
  };
}

class BannerData {
  final String id;
  final String title;
  final String imageUrl;
  BannerData({required this.id, required this.title, required this.imageUrl});
  factory BannerData.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return BannerData(id: doc.id, title: data['title'] ?? '', imageUrl: data['imageUrl'] ?? '');
  }
  Map<String, dynamic> toMap() => {'title': title, 'imageUrl': imageUrl};
}

class CartItem {
  final Product product;
  final String? preOrderDate;
  final String? selectedColor;
  final String? selectedSize;
  CartItem(this.product, {this.preOrderDate, this.selectedColor, this.selectedSize});
}

class Order {
  final String id;
  final String item;
  String status;
  final String userLogin;
  final String? readyDate;
  final String? color;
  final String? size;

  Order({required this.id, required this.item, required this.status, required this.userLogin, this.readyDate, this.color, this.size});

  factory Order.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Order(
      id: doc.id,
      item: data['item'] ?? '',
      status: data['status'] ?? 'НОВЫЙ',
      userLogin: data['userLogin'] ?? '',
      readyDate: data['readyDate'],
      color: data['color'],
      size: data['size'],
    );
  }

  Map<String, dynamic> toMap() => {
    'item': item,
    'status': status,
    'userLogin': userLogin,
    'readyDate': readyDate,
    'color': color,
    'size': size,
  };
}

class UserData {
  final String id;
  final String login;
  final String password;
  final String role;
  int totalSpent;

  UserData({required this.id, required this.login, required this.password, required this.role, this.totalSpent = 0});

  factory UserData.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return UserData(
      id: doc.id,
      login: data['login'] ?? '',
      password: data['password'] ?? '',
      role: data['role'] ?? '',
      totalSpent: data['totalSpent'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'login': login,
    'password': password,
    'role': role,
    'totalSpent': totalSpent,
  };
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> initDatabase() async {
    try {
      final productSnap = await _db.collection('products').limit(1).get();
      if (productSnap.docs.isEmpty) {
        await _db.collection('products').add({
          'name': 'ШЁЛКОВАЯ РУБАШКА',
          'price': '12000 KZT',
          'isInStock': true,
          'description': '100% натуральный шёлк.',
          'category': 'РУБАШКИ',
          'colors': ['БЕЛЫЙ', 'ЧЕРНЫЙ'],
          'sizes': ['S', 'M', 'L'],
          'imageUrls': []
        });
      }

      final userSnap = await _db.collection('users').limit(1).get();
      if (userSnap.docs.isEmpty) {
        await _db.collection('users').add({'login': 'admin', 'password': 'admin', 'role': 'АДМИН', 'totalSpent': 0});
        await _db.collection('users').add({'login': 'user', 'password': '123', 'role': 'КЛИЕНТ', 'totalSpent': 0});
      }
    } catch (e) {
      debugPrint("Firestore Init Error: $e");
    }
  }

  Future<List<Product>> getProducts() async {
    var snap = await _db.collection('products').get();
    return snap.docs.map((doc) => Product.fromFirestore(doc)).toList();
  }

  Future<List<UserData>> getUsers() async {
    var snap = await _db.collection('users').get();
    return snap.docs.map((doc) => UserData.fromFirestore(doc)).toList();
  }

  Future<List<Order>> getOrders() async {
    var snap = await _db.collection('orders').get();
    return snap.docs.map((doc) => Order.fromFirestore(doc)).toList();
  }

  Future<List<BannerData>> getBanners() async {
    var snap = await _db.collection('banners').get();
    return snap.docs.map((doc) => BannerData.fromFirestore(doc)).toList();
  }

  Future<void> addProduct(Product p) => _db.collection('products').add(p.toMap());
  Future<void> deleteProduct(String id) => _db.collection('products').doc(id).delete();

  Future<void> addUser(UserData u) => _db.collection('users').add(u.toMap());
  Future<void> deleteUser(String id) => _db.collection('users').doc(id).delete();

  Future<void> addBanner(BannerData b) => _db.collection('banners').add(b.toMap());
  Future<void> deleteBanner(String id) => _db.collection('banners').doc(id).delete();

  Future<void> addOrder(Order o) => _db.collection('orders').add(o.toMap());
  Future<void> updateOrderStatus(String id, String status) => _db.collection('orders').doc(id).update({'status': status});

  Future<void> incrementUserSpent(String login, int amount) async {
    var snap = await _db.collection('users').where('login', isEqualTo: login).limit(1).get();
    if (snap.docs.isNotEmpty) {
      var doc = snap.docs.first;
      int current = doc.data()['totalSpent'] ?? 0;
      await doc.reference.update({'totalSpent': current + amount});
    }
  }
}

class LoyaltyInfo {
  final String level;
  final Color color;
  final double progress;
  final int nextThreshold;
  LoyaltyInfo(this.level, this.color, this.progress, this.nextThreshold);
}

LoyaltyInfo getLoyaltyInfo(int spent) {
  if (spent < 100000) return LoyaltyInfo("BRONZE", Colors.orange[800]!, spent / 100000, 100000);
  if (spent < 300000) return LoyaltyInfo("SILVER", Colors.grey[400]!, (spent - 100000) / 200000, 300000);
  if (spent < 700000) return LoyaltyInfo("GOLD", Colors.yellow[700]!, (spent - 300000) / 400000, 700000);
  if (spent < 1500000) return LoyaltyInfo("PLATINUM", Colors.cyan[300]!, (spent - 700000) / 800000, 1500000);
  return LoyaltyInfo("DIAMOND", Colors.blue[900]!, 1.0, 0);
}

class AvishuApp extends StatelessWidget {
  const AvishuApp({super.key});
  @override Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFFFFFFF), fontFamily: 'Helvetica', primaryColor: Colors.black), home: const VideoSplashScreen());
  }
}

class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});
  @override State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset("assets/splash.mp4")
      ..initialize().then((_) {
        setState(() { _initialized = true; });
        _controller.play();
      });
    
    _controller.addListener(() {
      if (_controller.value.position >= _controller.value.duration) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RootScreen()));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _initialized
            ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller))
            : const CircularProgressIndicator(color: Colors.black),
      ),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  String? currentRole;
  String? currentUserLogin;
  final Map<String, bool> roleAuth = {'КЛИЕНТ': false, 'ФРАНЧАЙЗИ': false, 'ЦЕХ': false, 'АДМИН': false};
  final FirestoreService firestoreService = FirestoreService();
  List<Product> products = [];
  List<Order> orders = [];
  List<UserData> users = [];
  List<BannerData> banners = [];
  List<CartItem> cart = [];
  bool isLoading = true;

  @override void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    try {
      await firestoreService.initDatabase();
      products = await firestoreService.getProducts();
      orders = await firestoreService.getOrders();
      users = await firestoreService.getUsers();
      banners = await firestoreService.getBanners();
    } catch (e) {
      debugPrint("Data Loading Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _addOrderFromCart() async {
    if (currentUserLogin == null) return;
    for (var item in cart) {
      final newOrder = Order(
        id: '',
        item: "${item.product.name} (${item.selectedColor}, ${item.selectedSize})",
        status: "НОВЫЙ",
        userLogin: currentUserLogin!,
        readyDate: item.preOrderDate,
        color: item.selectedColor,
        size: item.selectedSize,
      );
      await firestoreService.addOrder(newOrder);
    }
    cart.clear();
    orders = await firestoreService.getOrders();
    setState(() {});
  }

  void _updateOrderStatusAndLoyalty(Order o) async {
    await firestoreService.updateOrderStatus(o.id, o.status);
    if (o.status == 'ГОТОВО') {
      final pName = o.item.split(' (').first;
      final p = products.firstWhere((prod) => prod.name == pName, orElse: () => Product(id: '', name: '', price: '0 KZT', isInStock: false, description: '', category: '', colors: [], sizes: [], imageUrls: []));
      int val = int.tryParse(p.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      await firestoreService.incrementUserSpent(o.userLogin, val);
      users = await firestoreService.getUsers();
    }
    setState(() {});
  }

  @override Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));
    if (currentRole == null) return Scaffold(body: WelcomeScreen(onRoleSelected: (role) => setState(() => currentRole = role)));

    UserData? currentUserData;
    if (currentUserLogin != null) {
      try { currentUserData = users.firstWhere((u) => u.login == currentUserLogin); } catch(_) {}
    }

    if (!(roleAuth[currentRole!] ?? false)) return Scaffold(body: LoginScreen(
      roleName: currentRole!,
      users: users,
      onLogin: (login) {
        setState(() {
          currentUserLogin = login;
          roleAuth[currentRole!] = true;
        });
      },
      onCancel: () => setState(() => currentRole = null),
      onRegisterSuccess: (login, pass) async {
        final newUser = UserData(id: '', login: login, password: pass, role: 'КЛИЕНТ', totalSpent: 0);
        await firestoreService.addUser(newUser);
        users = await firestoreService.getUsers();
        setState(() {
          currentUserLogin = login;
          roleAuth['КЛИЕНТ'] = true;
          currentRole = 'КЛИЕНТ';
        });
      },
    ));

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _buildRoleSelector(),
          const Divider(height: 1, color: Colors.black),
          Expanded(child: _buildBodyByRole(currentUserData)),
        ]),
      ),
    );
  }

  Widget _buildRoleSelector() {
    final visibleRoles = ['КЛИЕНТ', 'ФРАНЧАЙЗИ', 'ЦЕХ', 'АДМИН'].where((role) => roleAuth[role] ?? false).toList();
    return Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: visibleRoles.map((role) => GestureDetector(onTap: () => setState(() => currentRole = role), child: Text(role, style: TextStyle(fontSize: 10, fontWeight: currentRole == role ? FontWeight.bold : FontWeight.w300, decoration: currentRole == role ? TextDecoration.underline : null)))).toList()));
  }

  Widget _buildBodyByRole(UserData? currentUser) {
    if (currentRole == 'КЛИЕНТ') return ClientInterface(
        user: currentUser,
        products: products,
        banners: banners,
        orders: orders.where((o) => o.userLogin == currentUserLogin).toList(),
        cart: cart,
        onCartUpdate: () => setState(() {}),
        onCheckout: _addOrderFromCart,
        onLogout: () async {
          setState(() { roleAuth['КЛИЕНТ'] = false; currentRole = null; currentUserLogin = null; });
        }
    );
    if (currentRole == 'ФРАНЧАЙЗИ') return FranchiseeInterface(orders: orders, products: products, onLogout: () async {
      setState(() { roleAuth['ФРАНЧАЙЗИ'] = false; currentRole = null; currentUserLogin = null; });
    }, onUpdate: _updateOrderStatusAndLoyalty);
    if (currentRole == 'ЦЕХ') return ProductionInterface(orders: orders, onLogout: () async {
      setState(() { roleAuth['ЦЕХ'] = false; currentRole = null; currentUserLogin = null; });
    }, onUpdate: _updateOrderStatusAndLoyalty);
    return AdminInterface(
      products: products,
      users: users,
      banners: banners,
      onLogout: () async {
        setState(() { roleAuth['АДМИН'] = false; currentRole = null; currentUserLogin = null; });
      },
      onAddProduct: (p) async { await firestoreService.addProduct(p); products = await firestoreService.getProducts(); setState(() {}); },
      onDeleteProduct: (id) async { await firestoreService.deleteProduct(id); products = await firestoreService.getProducts(); setState(() {}); },
      onAddUser: (u) async { await firestoreService.addUser(u); users = await firestoreService.getUsers(); setState(() {}); },
      onDeleteUser: (id) async { await firestoreService.deleteUser(id); users = await firestoreService.getUsers(); setState(() {}); },
      onAddBanner: (b) async { await firestoreService.addBanner(b); banners = await firestoreService.getBanners(); setState(() {}); },
      onDeleteBanner: (id) async { await firestoreService.deleteBanner(id); banners = await firestoreService.getBanners(); setState(() {}); },
      firestoreService: firestoreService,
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  final Function(String) onRoleSelected;
  const WelcomeScreen({super.key, required this.onRoleSelected});
  @override State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final String logoText = "AVISHU";
  @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000)); _controller.forward(); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(logoText.length, (index) {
        double center = (logoText.length - 1) / 2;
        double distance = (index - center).abs();
        double start = (distance - 0.5) * 0.2; if (start < 0) start = 0;
        return AnimatedBuilder(animation: _controller, builder: (context, child) {
          final op = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Interval(start, start + 0.4, curve: Curves.easeIn)));
          final sc = Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Interval(start, start + 0.5, curve: Curves.elasticOut)));
          return Opacity(opacity: op.value, child: Transform.scale(scale: sc.value, child: Text(logoText[index], style: const TextStyle(fontSize: 70, fontWeight: FontWeight.w900, letterSpacing: -2))));
        });
      })),
      const SizedBox(height: 80),
      ...['КЛИЕНТ', 'ФРАНЧАЙЗИ', 'ЦЕХ', 'АДМИН'].map((r) => Padding(padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 10), child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), side: const BorderSide(color: Colors.black), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), onPressed: () => widget.onRoleSelected(r), child: Text(r, style: const TextStyle(color: Colors.black, letterSpacing: 2, fontSize: 11))))).toList()
    ]));
  }
}

class LoginScreen extends StatefulWidget {
  final String roleName;
  final List<UserData> users;
  final Function(String) onLogin;
  final VoidCallback onCancel;
  final Function(String, String) onRegisterSuccess;
  const LoginScreen({super.key, required this.roleName, required this.users, required this.onLogin, required this.onCancel, required this.onRegisterSuccess});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _lC = TextEditingController();
  final TextEditingController _pC = TextEditingController();
  String err = '';
  bool isRegisterMode = false;

  void _handleAction() {
    String login = _lC.text.trim();
    String password = _pC.text.trim();

    if (login.isEmpty || password.isEmpty) {
      setState(() => err = 'Поля не могут быть пустыми');
      return;
    }

    if (isRegisterMode) {
      if (widget.users.any((u) => u.login == login)) {
        setState(() => err = 'Логин уже занят');
      } else {
        widget.onRegisterSuccess(login, password);
      }
    } else {
      if (widget.users.any((u) => u.login == login && u.password == password && u.role == widget.roleName)) {
        widget.onLogin(login);
      } else {
        setState(() => err = 'Ошибка доступа: проверьте данные');
      }
    }
  }

  @override Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.lock_outline, size: 50), const SizedBox(height: 20),
      Text(isRegisterMode ? "РЕГИСТРАЦИЯ" : "ВХОД: ${widget.roleName}", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      const SizedBox(height: 40),
      TextField(controller: _lC, decoration: const InputDecoration(hintText: "ЛОГИН", enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)))),
      const SizedBox(height: 15),
      TextField(controller: _pC, obscureText: true, decoration: const InputDecoration(hintText: "ПАРОЛЬ", enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)))),
      if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err, style: const TextStyle(color: Colors.red, fontSize: 10))),
      const SizedBox(height: 30),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), onPressed: _handleAction, child: Text(isRegisterMode ? "ЗАРЕГИСТРИРОВАТЬСЯ" : "ВОЙТИ"))),
      if (widget.roleName == 'КЛИЕНТ') TextButton(onPressed: () => setState(() { isRegisterMode = !isRegisterMode; err = ''; }), child: Text(isRegisterMode ? "УЖЕ ЕСТЬ АККАУНТ? ВОЙТИ" : "НЕТ АККАУНТА? РЕГИСТРАЦИЯ", style: const TextStyle(color: Colors.black, fontSize: 10))),
      TextButton(onPressed: widget.onCancel, child: const Text("НАЗАД", style: TextStyle(color: Colors.grey, fontSize: 10)))
    ]));
  }
}

class ClientInterface extends StatefulWidget {
  final UserData? user;
  final List<Product> products; final List<BannerData> banners; final List<Order> orders; final List<CartItem> cart; final VoidCallback onCartUpdate; final VoidCallback onCheckout; final VoidCallback onLogout;
  const ClientInterface({super.key, this.user, required this.products, required this.banners, required this.orders, required this.cart, required this.onCartUpdate, required this.onCheckout, required this.onLogout});
  @override State<ClientInterface> createState() => _ClientInterfaceState();
}

class _ClientInterfaceState extends State<ClientInterface> {
  int _sI = 0;
  String _selectedCategory = 'ВСЕ';
  String _selectedColor = 'ВСЕ';
  String _selectedSize = 'ВСЕ';
  String _sortOrder = 'ПО УМОЛЧАНИЮ';
  RangeValues _priceRange = const RangeValues(0, 200000);

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: _sI == 0 ? _buildShowcase() : _buildProfile(),
      bottomNavigationBar: Container(decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black, width: 0.5))), child: BottomNavigationBar(currentIndex: _sI, onTap: (i) => setState(() => _sI = i), selectedItemColor: Colors.black, unselectedItemColor: Colors.grey, selectedFontSize: 10, unselectedFontSize: 10, elevation: 0, type: BottomNavigationBarType.fixed, items: const [BottomNavigationBarItem(icon: Icon(Icons.grid_view, size: 20), label: "ВИТРИНА"), BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 20), label: "ПРОФИЛЬ")])),
      floatingActionButton: _sI == 0 && widget.cart.isNotEmpty ? FloatingActionButton.extended(backgroundColor: Colors.black, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), onPressed: _showCart, label: Text("КОРЗИНА (${widget.cart.length})", style: const TextStyle(fontSize: 10, color: Colors.white)), icon: const Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.white)) : null,
    );
  }

  Widget _buildShowcase() {
    List<Product> displayList = List.from(widget.products);

    if (_selectedCategory != 'ВСЕ') {
      displayList = displayList.where((p) => p.category == _selectedCategory).toList();
    }

    if (_selectedColor != 'ВСЕ') {
      displayList = displayList.where((p) => p.colors.contains(_selectedColor)).toList();
    }

    if (_selectedSize != 'ВСЕ') {
      displayList = displayList.where((p) => p.sizes.contains(_selectedSize)).toList();
    }

    displayList = displayList.where((p) {
      int price = _parsePrice(p.price);
      return price >= _priceRange.start && price <= _priceRange.end;
    }).toList();

    if (_sortOrder == 'ДЕШЕВЛЕ') {
      displayList.sort((a, b) => _parsePrice(a.price).compareTo(_parsePrice(b.price)));
    } else if (_sortOrder == 'ДОРОЖЕ') {
      displayList.sort((a, b) => _parsePrice(b.price).compareTo(_parsePrice(a.price)));
    }

    return ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
      const SizedBox(height: 20),
      const Text("AVISHU", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -2)),
      const Text("КОЛЛЕКЦИЯ 2026", style: TextStyle(fontSize: 12, letterSpacing: 4)),
      const SizedBox(height: 20),

      const Text("КАТЕГОРИИ", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: ['ВСЕ', ...APP_CATEGORIES].map((cat) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _buildSquareButton(cat, _selectedCategory == cat, (val) => setState(() => _selectedCategory = cat)),
        )).toList()),
      ),

      const SizedBox(height: 10),
      const Text("ЦВЕТА", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: ['ВСЕ', ...APP_COLORS].map((col) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _buildSquareButton(col, _selectedColor == col, (val) => setState(() => _selectedColor = col)),
        )).toList()),
      ),

      const SizedBox(height: 10),
      const Text("РАЗМЕРЫ", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: ['ВСЕ', ...APP_SIZES].map((siz) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _buildSquareButton(siz, _selectedSize == siz, (val) => setState(() => _selectedSize = siz)),
        )).toList()),
      ),

      const SizedBox(height: 20),
      if (widget.banners.isNotEmpty) ...[
        ...widget.banners.map((b) => Container(
          height: 400, width: double.infinity, margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: Colors.grey[200], image: DecorationImage(image: MemoryImage(base64Decode(b.imageUrl)), fit: BoxFit.cover)),
          child: Container(color: Colors.black.withOpacity(0.2), child: Center(child: Text(b.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 8)))),
        ))
      ] else ...[
        Container(height: 300, color: Colors.grey[100], child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 50))),
      ],
      const SizedBox(height: 20),

      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("ДИАПАЗОН ЦЕНЫ", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
          Text("${_priceRange.start.round()} - ${_priceRange.end.round()} ₸", style: const TextStyle(fontSize: 8, color: Colors.grey)),
        ]),
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: 200000,
          divisions: 20,
          activeColor: Colors.black,
          inactiveColor: Colors.grey[200],
          labels: RangeLabels(_priceRange.start.round().toString(), _priceRange.end.round().toString()),
          onChanged: (values) => setState(() => _priceRange = values),
        ),
      ]),

      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("КАТАЛОГ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
        DropdownButton<String>(
          value: _sortOrder,
          underline: const SizedBox(),
          style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
          items: ["ПО УМОЛЧАНИЮ", "ДЕШЕВЛЕ", "ДОРОЖЕ"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _sortOrder = v!),
        )
      ]),

      const SizedBox(height: 10),
      ...displayList.map((p) => ListTile(
          leading: buildProductImage(p.imageUrls.isNotEmpty ? p.imageUrls.first : null, width: 50, height: 50),
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(p.category, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          trailing: Text(p.price, style: const TextStyle(fontSize: 14)),
          onTap: () => _showProductDetails(p)))
    ]);
  }

  Widget _buildSquareButton(String label, bool isSelected, Function(bool) onSelected) {
    return GestureDetector(
      onTap: () => onSelected(true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          border: Border.all(color: Colors.black, width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showProductDetails(Product p) {
    String? selectedColor = p.colors.isNotEmpty ? p.colors.first : null;
    String? selectedSize = p.sizes.isNotEmpty ? p.sizes.first : null;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        builder: (context) => StatefulBuilder(builder: (context, setS) => SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p.imageUrls.isNotEmpty)
              SizedBox(
                height: 550, // Significant increase in height
                width: double.infinity,
                child: PageView.builder(
                  itemCount: p.imageUrls.length,
                  itemBuilder: (context, index) => buildProductImage(p.imageUrls[index], width: double.infinity, height: 550, fit: BoxFit.cover),
                ),
              )
            else
              buildProductImage(null, width: double.infinity, height: 400, fit: BoxFit.cover),
            
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (p.imageUrls.length > 1)
                  const Center(child: Padding(
                    padding: EdgeInsets.only(bottom: 15.0),
                    child: Text("ЛИСТАЙТЕ ФОТО →", style: TextStyle(fontSize: 8, color: Colors.grey, letterSpacing: 1, fontWeight: FontWeight.bold)),
                  )),
                Text(p.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(p.category, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 10),
                Text(p.price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(p.description, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 20),
                if (p.colors.isNotEmpty) ...[
                  const Text("ЦВЕТ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: p.colors.map((c) => _buildSquareButton(c, selectedColor == c, (v) => setS(() => selectedColor = c))).toList()),
                  const SizedBox(height: 10),
                ],
                if (p.sizes.isNotEmpty) ...[
                  const Text("РАЗМЕР", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: p.sizes.map((s) => _buildSquareButton(s, selectedSize == s, (v) => setS(() => selectedSize = s))).toList()),
                  const SizedBox(height: 20),
                ],
                ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                    onPressed: () async {
                      if (p.isInStock) {
                        widget.cart.add(CartItem(p, selectedColor: selectedColor, selectedSize: selectedSize));
                        widget.onCartUpdate();
                        Navigator.pop(context);
                      } else {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          widget.cart.add(CartItem(p, preOrderDate: "${picked.day}.${picked.month}.${picked.year}", selectedColor: selectedColor, selectedSize: selectedSize));
                          widget.onCartUpdate();
                          Navigator.pop(context);
                        }
                      }
                    },
                    child: Text(p.isInStock ? "В КОРЗИНУ" : "ПРЕДЗАКАЗАТЬ")
                )
              ]),
            ),
          ]),
        ))
    );
  }

  void _showCart() => showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), builder: (context) => Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text("КОРЗИНА", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)), const SizedBox(height: 20),
    ...widget.cart.map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("${item.product.name} (${item.selectedColor}, ${item.selectedSize})", style: const TextStyle(fontSize: 12)),
        if (item.preOrderDate != null) Text("ПРЕДЗАКАЗ: ${item.preOrderDate}", style: const TextStyle(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.bold)),
      ]),
      Text(item.product.price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
    ]))),
    const Divider(height: 40), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), onPressed: () { widget.onCheckout(); Navigator.pop(context); }, child: const Text("ОФОРМИТЬ ЗАКАЗ"))
  ])));

  Widget _buildProfile() {
    final li = getLoyaltyInfo(widget.user?.totalSpent ?? 0);
    return ListView(padding: const EdgeInsets.all(30), children: [
      const Text("ЛИЧНЫЙ КАБИНЕТ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 40), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("ПРОГРАММА ЛОЯЛЬНОСТИ: ${li.level}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        Text("${widget.user?.totalSpent} / ${li.nextThreshold} ₸", style: const TextStyle(fontSize: 8, color: Colors.grey))
      ]),
      const SizedBox(height: 10), LinearProgressIndicator(value: li.progress, backgroundColor: const Color(0xFFF5F5F5), color: li.color, minHeight: 2),
      const SizedBox(height: 40), const Text("МОИ ЗАКАЗЫ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
      const SizedBox(height: 15),
      ...widget.orders.reversed.map((o) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(o.id.length > 5 ? o.id.substring(0, 5).toUpperCase() : "ORDER", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(o.item, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          if (o.readyDate != null) Text("ГОТОВНОСТЬ: ${o.readyDate}", style: const TextStyle(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.bold)),
        ]),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: o.status == 'ГОТОВО' ? Colors.green : Colors.black, child: Text(o.status, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))
      ]))),
      const SizedBox(height: 40), Center(child: TextButton(onPressed: widget.onLogout, child: const Text("ВЫЙТИ ИЗ АККАУНТА", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))))
    ]);
  }
}

// --- ФРАНЧАЙЗИ ---
class FranchiseeInterface extends StatelessWidget {
  final List<Order> orders; final List<Product> products; final VoidCallback onLogout; final Function(Order) onUpdate;
  const FranchiseeInterface({super.key, required this.orders, required this.products, required this.onLogout, required this.onUpdate});

  @override Widget build(BuildContext context) {
    int totalMoney = 0;
    int completedCount = 0;
    for (var o in orders) {
      final pName = o.item.split(' (').first;
      final p = products.firstWhere((prod) => prod.name == pName, orElse: () => Product(id: '', name: '', price: '0 KZT', isInStock: false, description: '', category: '', colors: [], sizes: [], imageUrls: []));
      int val = int.tryParse(p.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      totalMoney += val;
      if (o.status == 'ГОТОВО') completedCount++;
    }
    double progress = orders.isEmpty ? 0 : (completedCount / orders.length);

    return Padding(padding: const EdgeInsets.all(25), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("БАШНЯ УПРАВЛЕНИЯ", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)), IconButton(onPressed: onLogout, icon: const Icon(Icons.logout, size: 20))]),
      const SizedBox(height: 30), Row(children: [
        _buildMetric("ВЫРУЧКА СЕГОДНЯ", "$totalMoney ₸"),
        const SizedBox(width: 15),
        _buildMetric("ЗАКАЗЫ", "$completedCount/${orders.length}", progress: progress, isP: true)
      ]),
      const SizedBox(height: 30), const Text("СПИСОК ЗАКАЗОВ", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      Expanded(child: ListView.builder(itemCount: orders.length, itemBuilder: (context, i) => _buildOrderCard(orders[orders.length - 1 - i])))
    ]));
  }
  Widget _buildMetric(String l, String v, {double progress = 0, bool isP = false}) => Expanded(child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 0.5)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey)), Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), if (isP) LinearProgressIndicator(value: progress, color: Colors.black, backgroundColor: Color(0xFFEEEEEE))])));
  Widget _buildOrderCard(Order o) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(o.id.length > 5 ? o.id.substring(0, 5).toUpperCase() : "ORDER", style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(o.item, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      if (o.readyDate != null) Text("ДАТА ПРЕДЗАКАЗА: ${o.readyDate}", style: const TextStyle(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.bold)),
    ]),
    Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: o.status == 'НОВЫЙ' ? Colors.red : (o.status == 'ГОТОВО' ? Colors.green : Colors.blue), child: Text(o.status, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))), if (o.status == 'НОВЫЙ') IconButton(icon: const Icon(Icons.check_circle_outline, size: 20), onPressed: () { o.status = 'ПОДТВЕРЖДЕН'; onUpdate(o); })])
  ]));
}

// --- ЦЕХ ---
class ProductionInterface extends StatefulWidget {
  final List<Order> orders; final VoidCallback onLogout; final Function(Order) onUpdate;
  const ProductionInterface({super.key, required this.orders, required this.onLogout, required this.onUpdate});
  @override State<ProductionInterface> createState() => _ProductionInterfaceState();
}
class _ProductionInterfaceState extends State<ProductionInterface> {
  Order? active;
  @override Widget build(BuildContext context) {
    final q = widget.orders.where((o) => o.status == 'ПОДТВЕРЖДЕН' || o.status == 'В ПРОИЗВОДСТВЕ').toList();
    if (active == null && q.isNotEmpty) active = q.first;
    return Container(color: const Color(0xFF1A1A1A), child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), color: Colors.white, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("ПЛАНШЕТ МАСТЕРА", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)), IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout, color: Colors.black))])),
      Expanded(child: Row(children: [
        Container(width: 150, decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.white12))), child: ListView(children: q.map((o) => GestureDetector(onTap: () => setState(() => active = o), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: active == o ? Colors.white10 : Colors.transparent, border: const Border(bottom: BorderSide(color: Colors.white10))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(o.id.length > 5 ? o.id.substring(0, 5).toUpperCase() : "ORDER", style: TextStyle(color: active == o ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
          if (o.readyDate != null) Text(o.readyDate!, style: const TextStyle(color: Colors.orange, fontSize: 8)),
        ])))).toList())),
        Expanded(child: active == null ? const Center(child: Text("НЕТ ЗАДАЧ", style: TextStyle(color: Colors.white38))) : Padding(padding: const EdgeInsets.all(40), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("ТЕКУЩАЯ ОПЕРАЦИЯ", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(active!.item, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text("ID: ${active!.id.length > 5 ? active!.id.substring(0, 5).toUpperCase() : "ORDER"}", style: const TextStyle(color: Colors.white54, fontSize: 18)),
          if (active!.readyDate != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text("ДОЛЖНО БЫТЬ ГОТОВО: ${active!.readyDate}", style: const TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold))),
          const Spacer(),
          SizedBox(width: double.infinity, height: 120, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), onPressed: () { if (active!.status == 'ПОДТВЕРЖДЕН') active!.status = 'В ПРОИЗВОДСТВЕ'; else { active!.status = 'ГОТОВО'; } widget.onUpdate(active!); if (active!.status == 'ГОТОВО') setState(() { active = null; }); else setState(() {}); }, child: Text(active!.status == 'ПОДТВЕРЖДЕН' ? "НАЧАТЬ ПОШИВ" : "ЗАВЕРШИТЬ", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))))])))
      ]))
    ]));
  }
}

class AdminInterface extends StatefulWidget {
  final List<Product> products; final List<UserData> users; final List<BannerData> banners; final VoidCallback onLogout; final Function(Product) onAddProduct; final Function(String) onDeleteProduct; final Function(UserData) onAddUser; final Function(String) onDeleteUser; final Function(BannerData) onAddBanner; final Function(String) onDeleteBanner;
  final FirestoreService firestoreService;
  const AdminInterface({super.key, required this.products, required this.users, required this.banners, required this.onLogout, required this.onAddProduct, required this.onDeleteProduct, required this.onAddUser, required this.onDeleteUser, required this.onAddBanner, required this.onDeleteBanner, required this.firestoreService});
  @override State<AdminInterface> createState() => _AdminInterfaceState();
}
class _AdminInterfaceState extends State<AdminInterface> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override void initState() { super.initState(); _tabController = TabController(length: 3, vsync: this); }
  @override Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("АДМИН ПАНЕЛЬ", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)), IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout, size: 20))])),
      TabBar(controller: _tabController, labelColor: Colors.black, unselectedLabelColor: Colors.grey, indicatorColor: Colors.black, tabs: const [Tab(text: "ТОВАРЫ"), Tab(text: "ПЕРСОНАЛ"), Tab(text: "БАННЕРЫ")]),
      Expanded(child: TabBarView(controller: _tabController, children: [_buildProductList(), _buildUserList(), _buildBannerList()])),
    ]);
  }
  Widget _buildProductList() => Padding(padding: const EdgeInsets.all(25), child: Column(children: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 50), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), onPressed: _showAddProduct, child: const Text("ДОБАВИТЬ ТОВАР", style: TextStyle(color: Colors.white, fontSize: 10))), const SizedBox(height: 20), Expanded(child: ListView.builder(itemCount: widget.products.length, itemBuilder: (context, i) => ListTile(
      leading: buildProductImage(widget.products[i].imageUrls.isNotEmpty ? widget.products[i].imageUrls.first : null, width: 40, height: 40),
      title: Text(widget.products[i].name),
      subtitle: Text("${widget.products[i].category} - ${widget.products[i].price}"),
      trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => widget.onDeleteProduct(widget.products[i].id)))))]));
  Widget _buildUserList() => Padding(padding: const EdgeInsets.all(25), child: Column(children: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 50), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), onPressed: _showAddUser, child: const Text("ДОБАВИТЬ СОТРУДНИКА", style: TextStyle(color: Colors.white, fontSize: 10))), const SizedBox(height: 20), Expanded(child: ListView.builder(itemCount: widget.users.length, itemBuilder: (context, i) { if (widget.users[i].role == 'АДМИН') return const SizedBox.shrink(); return ListTile(title: Text(widget.users[i].login), subtitle: Text(widget.users[i].role), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => widget.onDeleteUser(widget.users[i].id))); }))]));
  Widget _buildBannerList() => Padding(padding: const EdgeInsets.all(25), child: Column(children: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 50), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), onPressed: _showAddBanner, child: const Text("ДОБАВИТЬ БАННЕР", style: TextStyle(color: Colors.white, fontSize: 10))), const SizedBox(height: 20), Expanded(child: ListView.builder(itemCount: widget.banners.length, itemBuilder: (context, i) => ListTile(
      leading: Container(width: 60, height: 40, decoration: BoxDecoration(image: DecorationImage(image: MemoryImage(base64Decode(widget.banners[i].imageUrl)), fit: BoxFit.cover))),
      title: Text(widget.banners[i].title),
      trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => widget.onDeleteBanner(widget.banners[i].id)))))]));

  void _showAddProduct() async {
    String n = '', p = '', cat = APP_CATEGORIES.first, desc = '';
    List<String> col = [], siz = [];
    bool stock = true;
    List<File> selectedImages = [];
    bool isProcessing = false;

    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (context, setS) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text("НОВЫЙ ТОВАР"),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("ФОТОГРАФИИ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...selectedImages.map((img) => Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      height: 80, width: 80,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!)),
                      child: Image.file(img, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 0, top: 0,
                      child: GestureDetector(
                        onTap: () => setS(() => selectedImages.remove(img)),
                        child: Container(color: Colors.black54, child: const Icon(Icons.close, size: 16, color: Colors.white)),
                      ),
                    )
                  ],
                )),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                    if (pickedFile != null) setS(() => selectedImages.add(File(pickedFile.path)));
                  },
                  child: Container(
                    height: 80, width: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.add_a_photo_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(onChanged: (v)=>n=v, decoration: const InputDecoration(hintText: "Название")),
          TextField(onChanged: (v)=>p=v, decoration: const InputDecoration(hintText: "Цена", suffixText: " KZT"), keyboardType: TextInputType.number),
          DropdownButton<String>(
            value: cat, isExpanded: true,
            items: APP_CATEGORIES.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setS(() => cat = v!),
          ),
          TextField(onChanged: (v)=>desc=v, decoration: const InputDecoration(hintText: "Описание")),
          const SizedBox(height: 10),
          const Text("ДОСТУПНЫЕ ЦВЕТА", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Wrap(children: APP_COLORS.map((c) => FilterChip(
              label: Text(c, style: const TextStyle(fontSize: 8)),
              selected: col.contains(c),
              onSelected: (v) => setS(() => v ? col.add(c) : col.remove(c))
          )).toList()),
          const Text("ДОСТУПНЫЕ РАЗМЕРЫ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Wrap(children: APP_SIZES.map((s) => FilterChip(
              label: Text(s, style: const TextStyle(fontSize: 8)),
              selected: siz.contains(s),
              onSelected: (v) => setS(() => v ? siz.add(s) : siz.remove(s))
          )).toList()),
          Row(children: [const Text("В наличии:", style: TextStyle(fontSize: 12)), Checkbox(value: stock, onChanged: (v) => setS(() => stock = v!))]),
          if (isProcessing) const LinearProgressIndicator(),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("ОТМЕНА")),
          TextButton(onPressed: isProcessing ? null : () async {
            if (n.isEmpty || selectedImages.isEmpty) return;
            setS(() => isProcessing = true);

            List<String> base64Images = [];
            for (var imgFile in selectedImages) {
              final bytes = await imgFile.readAsBytes();
              base64Images.add(base64Encode(bytes));
            }

            widget.onAddProduct(Product(id: '', name: n, price: "$p KZT", isInStock: stock, description: desc, category: cat, colors: col, sizes: siz, imageUrls: base64Images));
            Navigator.pop(c);
          }, child: const Text("ОК"))
        ]
    )));
  }
  void _showAddUser() { String l = '', p = '', r = 'ФРАНЧАЙЗИ'; showDialog(context: context, builder: (c) => StatefulBuilder(builder: (context, setS) => AlertDialog(shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), title: const Text("НОВЫЙ СОТРУДНИК"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(onChanged: (v)=>l=v, decoration: const InputDecoration(hintText: "Логин")), TextField(onChanged: (v)=>p=v, decoration: const InputDecoration(hintText: "Пароль")), const SizedBox(height: 10), DropdownButton<String>(value: r, isExpanded: true, items: ['ФРАНЧАЙЗИ', 'ЦЕХ', 'АДМИН'].map((String val) => DropdownMenuItem(value: val, child: Text(val))).toList(), onChanged: (v) => setS(() => r = v!))]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("ОТМЕНА")), TextButton(onPressed: () { widget.onAddUser(UserData(id: '', login: l, password: p, role: r, totalSpent: 0)); Navigator.pop(c); }, child: const Text("ОК"))]))); }
  void _showAddBanner() {
    String t = ''; File? img; bool processing = false;
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (context, setS) => AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: const Text("НОВЫЙ БАННЕР"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: () async {
            final picker = ImagePicker();
            final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
            if (pickedFile != null) setS(() => img = File(pickedFile.path));
          },
          child: Container(height: 100, width: double.infinity, color: Colors.grey[200], child: img == null ? const Icon(Icons.add_a_photo_outlined) : Image.file(img!, fit: BoxFit.cover)),
        ),
        TextField(onChanged: (v)=>t=v, decoration: const InputDecoration(hintText: "Заголовок")),
        if (processing) const LinearProgressIndicator(),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("ОТМЕНА")),
        TextButton(onPressed: processing ? null : () async {
          if (img == null || t.isEmpty) return;
          setS(() => processing = true);
          final bytes = await img!.readAsBytes();
          widget.onAddBanner(BannerData(id: '', title: t, imageUrl: base64Encode(bytes)));
          Navigator.pop(c);
        }, child: const Text("ОК"))
      ],
    )));
  }
}