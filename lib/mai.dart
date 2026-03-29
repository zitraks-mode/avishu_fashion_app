import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AvishuApp());
}

// --- МОДЕЛИ ДАННЫХ ---
class Product {
  final String name;
  final String price;
  final bool isInStock;
  final String description;
  Product(this.name, this.price, this.isInStock, this.description);
}

class Order {
  final String id;
  final String item;
  String status;
  Order(this.id, this.item, this.status);
}

class UserData {
  final String login;
  final String password;
  final String role;
  UserData(this.login, this.password, this.role);
}

// --- СЕРВИС EXCEL ---
class ExcelService {
  static const String fileName = "fashion_data.xlsx";

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File(p.join(directory.path, fileName));
  }

  Future<void> initExcel() async {
    final file = await _localFile;
    if (!await file.exists()) {
      var excel = Excel.createExcel();

      Sheet productSheet = excel['Products'];
      productSheet.appendRow([TextCellValue('Название'), TextCellValue('Цена'), TextCellValue('В наличии'), TextCellValue('Описание')]);
      productSheet.appendRow([TextCellValue('ШЁЛКОВАЯ РУБАШКА'), TextCellValue('12000 KZT'), TextCellValue('true'), TextCellValue('100% натуральный шёлк.')]);
      productSheet.appendRow([TextCellValue('ШЕРСТЯНЫЕ БРЮКИ'), TextCellValue('50000 KZT'), TextCellValue('false'), TextCellValue('Итальянская шерсть премиум качества.')]);

      Sheet orderSheet = excel['Orders'];
      orderSheet.appendRow([TextCellValue('ID'), TextCellValue('Товар'), TextCellValue('Статус')]);

      Sheet userSheet = excel['Users'];
      userSheet.appendRow([TextCellValue('Логин'), TextCellValue('Пароль'), TextCellValue('Роль')]);
      userSheet.appendRow([TextCellValue('admin'), TextCellValue('admin'), TextCellValue('АДМИН')]);
      userSheet.appendRow([TextCellValue('user'), TextCellValue('123'), TextCellValue('КЛИЕНТ')]);
      userSheet.appendRow([TextCellValue('fran'), TextCellValue('123'), TextCellValue('ФРАНЧАЙЗИ')]);
      userSheet.appendRow([TextCellValue('master'), TextCellValue('123'), TextCellValue('ЦЕХ')]);

      var fileBytes = excel.save();
      if (fileBytes != null) await file.writeAsBytes(fileBytes);
    }
  }

  Future<List<Product>> getProducts() async {
    final file = await _localFile;
    var bytes = await file.readAsBytes();
    var excel = Excel.decodeBytes(bytes);
    List<Product> products = [];
    var sheet = excel['Products'];
    for (var i = 1; i < sheet.maxRows; i++) {
      var row = sheet.row(i);
      if (row.isEmpty) continue;
      products.add(Product(row[0]?.value.toString() ?? '', row[1]?.value.toString() ?? '', row[2]?.value.toString().toLowerCase() == 'true', row[3]?.value.toString() ?? ''));
    }
    return products;
  }

  Future<List<UserData>> getUsers() async {
    final file = await _localFile;
    var bytes = await file.readAsBytes();
    var excel = Excel.decodeBytes(bytes);
    List<UserData> users = [];
    var sheet = excel['Users'];
    for (var i = 1; i < sheet.maxRows; i++) {
      var row = sheet.row(i);
      if (row.isEmpty) continue;
      users.add(UserData(row[0]?.value.toString() ?? '', row[1]?.value.toString() ?? '', row[2]?.value.toString() ?? ''));
    }
    return users;
  }

  Future<void> saveUsers(List<UserData> users) async {
    final file = await _localFile;
    var bytes = await file.readAsBytes();
    var excel = Excel.decodeBytes(bytes);
    excel.delete('Users');
    Sheet sheet = excel['Users'];
    sheet.appendRow([TextCellValue('Логин'), TextCellValue('Пароль'), TextCellValue('Роль')]);
    for (var u in users) {
      sheet.appendRow([TextCellValue(u.login), TextCellValue(u.password), TextCellValue(u.role)]);
    }
    var fileBytes = excel.save();
    if (fileBytes != null) await file.writeAsBytes(fileBytes);
  }

  Future<List<Order>> getOrders() async {
    final file = await _localFile;
    var bytes = await file.readAsBytes();
    var excel = Excel.decodeBytes(bytes);
    List<Order> orders = [];
    var sheet = excel['Orders'];
    for (var i = 1; i < sheet.maxRows; i++) {
      var row = sheet.row(i);
      if (row.isEmpty) continue;
      orders.add(Order(row[0]?.value.toString() ?? '', row[1]?.value.toString() ?? '', row[2]?.value.toString() ?? ''));
    }
    return orders;
  }

  Future<void> saveOrders(List<Order> orders) async {
    final file = await _localFile;
    var bytes = await file.readAsBytes();
    var excel = Excel.decodeBytes(bytes);
    excel.delete('Orders');
    Sheet sheet = excel['Orders'];
    sheet.appendRow([TextCellValue('ID'), TextCellValue('Товар'), TextCellValue('Статус')]);
    for (var o in orders) sheet.appendRow([TextCellValue(o.id), TextCellValue(o.item), TextCellValue(o.status)]);
    var fileBytes = excel.save();
    if (fileBytes != null) await file.writeAsBytes(fileBytes);
  }

  Future<void> saveProducts(List<Product> products) async {
    final file = await _localFile;
    var bytes = await file.readAsBytes();
    var excel = Excel.decodeBytes(bytes);
    excel.delete('Products');
    Sheet sheet = excel['Products'];
    sheet.appendRow([TextCellValue('Название'), TextCellValue('Цена'), TextCellValue('В наличии'), TextCellValue('Описание')]);
    for (var p in products) sheet.appendRow([TextCellValue(p.name), TextCellValue(p.price), TextCellValue(p.isInStock.toString()), TextCellValue(p.description)]);
    var fileBytes = excel.save();
    if (fileBytes != null) await file.writeAsBytes(fileBytes);
  }
}

class AvishuApp extends StatelessWidget {
  const AvishuApp({super.key});
  @override Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFFFFFFF), fontFamily: 'Helvetica', primaryColor: Colors.black), home: const RootScreen());
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  String? currentRole;
  final Map<String, bool> roleAuth = {'КЛИЕНТ': false, 'ФРАНЧАЙЗИ': false, 'ЦЕХ': false, 'АДМИН': false};
  final ExcelService excelService = ExcelService();
  List<Product> products = [];
  List<Order> orders = [];
  List<UserData> users = [];
  List<Product> cart = [];
  bool isLoading = true;

  @override void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    await excelService.initExcel();
    products = await excelService.getProducts();
    orders = await excelService.getOrders();
    users = await excelService.getUsers();

    // Проверка сохраненной сессии
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString('user_role');
    if (savedRole != null && roleAuth.containsKey(savedRole)) {
      setState(() {
        currentRole = savedRole;
        roleAuth[savedRole] = true;
      });
    }

    setState(() => isLoading = false);
  }

  Future<void> _saveSession(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
  }

  void _addOrderFromCart() async {
    for (var p in cart) {
      orders.add(Order("#${1000 + orders.length}", p.name, "НОВЫЙ"));
    }
    cart.clear();
    await excelService.saveOrders(orders);
    setState(() {});
  }

  @override Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));
    if (currentRole == null) return Scaffold(body: WelcomeScreen(onRoleSelected: (role) => setState(() => currentRole = role)));
    if (!(roleAuth[currentRole!] ?? false)) return Scaffold(body: LoginScreen(
      roleName: currentRole!,
      users: users,
      onLogin: () {
        _saveSession(currentRole!);
        setState(() => roleAuth[currentRole!] = true);
      },
      onCancel: () => setState(() => currentRole = null),
      onRegisterSuccess: (newUser) async {
        users.add(newUser);
        await excelService.saveUsers(users);
        _saveSession(newUser.role);
        setState(() {
          roleAuth[newUser.role] = true;
          currentRole = newUser.role;
        });
      },
    ));

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _buildRoleSelector(),
          const Divider(height: 1, color: Colors.black),
          Expanded(child: _buildBodyByRole()),
        ]),
      ),
    );
  }

  Widget _buildRoleSelector() {
    final visibleRoles = ['КЛИЕНТ', 'ФРАНЧАЙЗИ', 'ЦЕХ', 'АДМИН'].where((role) => roleAuth[role] ?? false).toList();
    return Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: visibleRoles.map((role) => GestureDetector(onTap: () => setState(() => currentRole = role), child: Text(role, style: TextStyle(fontSize: 10, fontWeight: currentRole == role ? FontWeight.bold : FontWeight.w300, decoration: currentRole == role ? TextDecoration.underline : null)))).toList()));
  }

  Widget _buildBodyByRole() {
    if (currentRole == 'КЛИЕНТ') return ClientInterface(products: products, orders: orders, cart: cart, onCartUpdate: () => setState(() {}), onCheckout: _addOrderFromCart, onLogout: () async {
      await _clearSession();
      setState(() { roleAuth['КЛИЕНТ'] = false; currentRole = null; });
    });
    if (currentRole == 'ФРАНЧАЙЗИ') return FranchiseeInterface(orders: orders, products: products, onLogout: () async {
      await _clearSession();
      setState(() { roleAuth['ФРАНЧАЙЗИ'] = false; currentRole = null; });
    }, onUpdate: () async { await excelService.saveOrders(orders); setState(() {}); });
    if (currentRole == 'ЦЕХ') return ProductionInterface(orders: orders, onLogout: () async {
      await _clearSession();
      setState(() { roleAuth['ЦЕХ'] = false; currentRole = null; });
    }, onUpdate: () async { await excelService.saveOrders(orders); setState(() {}); });
    return AdminInterface(
        products: products,
        users: users,
        onLogout: () async {
          await _clearSession();
          setState(() { roleAuth['АДМИН'] = false; currentRole = null; });
        },
        onUpdateProducts: () async { await excelService.saveProducts(products); setState(() {}); },
        onUpdateUsers: () async { await excelService.saveUsers(users); setState(() {}); }
    );
  }
}

// --- ЭКРАН ПРИВЕТСТВИЯ ---
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

// --- ЭКРАН ВХОДА И РЕГИСТРАЦИИ ---
class LoginScreen extends StatefulWidget {
  final String roleName;
  final List<UserData> users;
  final VoidCallback onLogin;
  final VoidCallback onCancel;
  final Function(UserData) onRegisterSuccess;
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
        widget.onRegisterSuccess(UserData(login, password, 'КЛИЕНТ'));
      }
    } else {
      if (widget.users.any((u) => u.login == login && u.password == password && u.role == widget.roleName)) {
        widget.onLogin();
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

// --- КЛИЕНТСКИЙ ИНТЕРФЕЙС ---
class ClientInterface extends StatefulWidget {
  final List<Product> products; final List<Order> orders; final List<Product> cart; final VoidCallback onCartUpdate; final VoidCallback onCheckout; final VoidCallback onLogout;
  const ClientInterface({super.key, required this.products, required this.orders, required this.cart, required this.onCartUpdate, required this.onCheckout, required this.onLogout});
  @override State<ClientInterface> createState() => _ClientInterfaceState();
}

class _ClientInterfaceState extends State<ClientInterface> {
  int _sI = 0;
  @override Widget build(BuildContext context) {
    return Scaffold(
      body: _sI == 0 ? _buildShowcase() : _buildProfile(),
      bottomNavigationBar: Container(decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black, width: 0.5))), child: BottomNavigationBar(currentIndex: _sI, onTap: (i) => setState(() => _sI = i), selectedItemColor: Colors.black, unselectedItemColor: Colors.grey, selectedFontSize: 10, unselectedFontSize: 10, elevation: 0, type: BottomNavigationBarType.fixed, items: const [BottomNavigationBarItem(icon: Icon(Icons.grid_view, size: 20), label: "ВИТРИНА"), BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 20), label: "ПРОФИЛЬ")])),
      floatingActionButton: _sI == 0 && widget.cart.isNotEmpty ? FloatingActionButton.extended(backgroundColor: Colors.black, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), onPressed: _showCart, label: Text("КОРЗИНА (${widget.cart.length})", style: const TextStyle(fontSize: 10, color: Colors.white)), icon: const Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.white)) : null,
    );
  }

  Widget _buildShowcase() => ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
    const SizedBox(height: 20), const Text("AVISHU", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -2)), const Text("КОЛЛЕКЦИЯ 2026", style: TextStyle(fontSize: 12, letterSpacing: 4)),
    const SizedBox(height: 30), Container(height: 300, color: Colors.grey[100], child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 50))),
    const SizedBox(height: 30), const Text("КАТАЛОГ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
    ...widget.products.map((p) => ListTile(title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text(p.isInStock ? "В НАЛИЧИИ" : "ПРЕДЗАКАЗ", style: TextStyle(fontSize: 9, color: p.isInStock ? Colors.green : Colors.orange)), trailing: Text(p.price, style: const TextStyle(fontSize: 14)), onTap: () { widget.cart.add(p); widget.onCartUpdate(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${p.name} добавлен в корзину"), duration: const Duration(seconds: 1))); })).toList()
  ]);

  void _showCart() => showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), builder: (context) => Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text("КОРЗИНА", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)), const SizedBox(height: 20),
    ...widget.cart.map((p) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(p.name, style: const TextStyle(fontSize: 12)), Text(p.price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]))).toList(),
    const Divider(height: 40), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), onPressed: () { widget.onCheckout(); Navigator.pop(context); }, child: const Text("ОФОРМИТЬ ЗАКАЗ"))
  ])));

  Widget _buildProfile() => ListView(padding: const EdgeInsets.all(30), children: [
    const Text("ЛИЧНЫЙ КАБИНЕТ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 40), const Text("ПРОГРАММА ЛОЯЛЬНОСТИ: SILVER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    const SizedBox(height: 10), const LinearProgressIndicator(value: 0.65, backgroundColor: Color(0xFFF5F5F5), color: Colors.black, minHeight: 2),
    const SizedBox(height: 40), const Text("МОИ ЗАКАЗЫ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
    const SizedBox(height: 15),
    ...widget.orders.reversed.map((o) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold)), Text(o.item, style: const TextStyle(fontSize: 10, color: Colors.grey))]), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: o.status == 'ГОТОВО' ? Colors.green : Colors.black, child: Text(o.status, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))]))).toList(),
    const SizedBox(height: 40), Center(child: TextButton(onPressed: widget.onLogout, child: const Text("ВЫЙТИ ИЗ АККАУНТА", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))))
  ]);
}

// --- ФРАНЧАЙЗИ ---
class FranchiseeInterface extends StatelessWidget {
  final List<Order> orders; final List<Product> products; final VoidCallback onLogout; final VoidCallback onUpdate;
  const FranchiseeInterface({super.key, required this.orders, required this.products, required this.onLogout, required this.onUpdate});

  @override Widget build(BuildContext context) {
    int totalMoney = 0;
    int completedCount = 0;
    for (var o in orders) {
      final p = products.firstWhere((prod) => prod.name == o.item, orElse: () => Product('', '0 KZT', false, ''));
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
  Widget _buildOrderCard(Order o) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold)), Text(o.item, style: const TextStyle(fontSize: 10, color: Colors.grey))]), Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: o.status == 'НОВЫЙ' ? Colors.red : (o.status == 'ГОТОВО' ? Colors.green : Colors.blue), child: Text(o.status, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))), if (o.status == 'НОВЫЙ') IconButton(icon: const Icon(Icons.check_circle_outline, size: 20), onPressed: () { o.status = 'ПОДТВЕРЖДЕН'; onUpdate(); })])]));
}

// --- ЦЕХ ---
class ProductionInterface extends StatefulWidget {
  final List<Order> orders; final VoidCallback onLogout; final VoidCallback onUpdate;
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
        Container(width: 150, decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.white12))), child: ListView(children: q.map((o) => GestureDetector(onTap: () => setState(() => active = o), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: active == o ? Colors.white10 : Colors.transparent, border: const Border(bottom: BorderSide(color: Colors.white10))), child: Text(o.id, style: TextStyle(color: active == o ? Colors.white : Colors.white70, fontWeight: FontWeight.bold))))).toList())),
        Expanded(child: active == null ? const Center(child: Text("НЕТ ЗАДАЧ", style: TextStyle(color: Colors.white38))) : Padding(padding: const EdgeInsets.all(40), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("ТЕКУЩАЯ ОПЕРАЦИЯ", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text(active!.item, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text("ID: ${active!.id}", style: const TextStyle(color: Colors.white54, fontSize: 18)), const Spacer(), SizedBox(width: double.infinity, height: 120, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), onPressed: () { setState(() { if (active!.status == 'ПОДТВЕРЖДЕН') active!.status = 'В ПРОИЗВОДСТВЕ'; else { active!.status = 'ГОТОВО'; active = null; } }); widget.onUpdate(); }, child: Text(active!.status == 'ПОДТВЕРЖДЕН' ? "НАЧАТЬ ПОШИВ" : "ЗАВЕРШИТЬ", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))))])))
      ]))
    ]));
  }
}

// --- АДМИН ---
class AdminInterface extends StatefulWidget {
  final List<Product> products; final List<UserData> users; final VoidCallback onLogout; final VoidCallback onUpdateProducts; final VoidCallback onUpdateUsers;
  const AdminInterface({super.key, required this.products, required this.users, required this.onLogout, required this.onUpdateProducts, required this.onUpdateUsers});
  @override State<AdminInterface> createState() => _AdminInterfaceState();
}
class _AdminInterfaceState extends State<AdminInterface> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); }
  @override Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("АДМИН ПАНЕЛЬ", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)), IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout, size: 20))])),
      TabBar(controller: _tabController, labelColor: Colors.black, unselectedLabelColor: Colors.grey, indicatorColor: Colors.black, tabs: const [Tab(text: "ТОВАРЫ"), Tab(text: "ПЕРСОНАЛ")]),
      Expanded(child: TabBarView(controller: _tabController, children: [_buildProductList(), _buildUserList()])),
    ]);
  }
  Widget _buildProductList() => Padding(padding: const EdgeInsets.all(25), child: Column(children: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 50), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), onPressed: _showAddProduct, child: const Text("ДОБАВИТЬ ТОВАР", style: TextStyle(color: Colors.white, fontSize: 10))), const SizedBox(height: 20), Expanded(child: ListView.builder(itemCount: widget.products.length, itemBuilder: (context, i) => ListTile(title: Text(widget.products[i].name), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () { widget.products.removeAt(i); widget.onUpdateProducts(); }))))]));
  Widget _buildUserList() => Padding(padding: const EdgeInsets.all(25), child: Column(children: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 50), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), onPressed: _showAddUser, child: const Text("ДОБАВИТЬ СОТРУДНИКА", style: TextStyle(color: Colors.white, fontSize: 10))), const SizedBox(height: 20), Expanded(child: ListView.builder(itemCount: widget.users.length, itemBuilder: (context, i) { if (widget.users[i].role == 'АДМИН') return const SizedBox.shrink(); return ListTile(title: Text(widget.users[i].login), subtitle: Text(widget.users[i].role), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () { widget.users.removeAt(i); widget.onUpdateUsers(); })); }))]));
  void _showAddProduct() { String n = '', p = ''; showDialog(context: context, builder: (c) => AlertDialog(shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), title: const Text("НОВЫЙ ТОВАР"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(onChanged: (v)=>n=v, decoration: const InputDecoration(hintText: "Название")), TextField(onChanged: (v)=>p=v, decoration: const InputDecoration(hintText: "Цена", suffixText: " KZT"), keyboardType: TextInputType.number)]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("ОТМЕНА")), TextButton(onPressed: () { widget.products.add(Product(n, "$p KZT", true, "")); widget.onUpdateProducts(); Navigator.pop(c); }, child: const Text("ОК"))])); }
  void _showAddUser() { String l = '', p = '', r = 'ФРАНЧАЙЗИ'; showDialog(context: context, builder: (c) => StatefulBuilder(builder: (context, setS) => AlertDialog(shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), title: const Text("НОВЫЙ СОТРУДНИК"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(onChanged: (v)=>l=v, decoration: const InputDecoration(hintText: "Логин")), TextField(onChanged: (v)=>p=v, decoration: const InputDecoration(hintText: "Пароль")), const SizedBox(height: 10), DropdownButton<String>(value: r, isExpanded: true, items: ['ФРАНЧАЙЗИ', 'ЦЕХ'].map((String val) => DropdownMenuItem(value: val, child: Text(val))).toList(), onChanged: (v) => setS(() => r = v!))]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("ОТМЕНА")), TextButton(onPressed: () { widget.users.add(UserData(l, p, r)); widget.onUpdateUsers(); Navigator.pop(c); }, child: const Text("ОК"))]))); }
}
