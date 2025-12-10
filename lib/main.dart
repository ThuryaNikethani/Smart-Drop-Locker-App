import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling for web
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(const DropLockApp());
}

//Storage helpers
final _secureStorage = const FlutterSecureStorage();

Future<void> _saveLogin({
  required String userId,
  required String phone,
  required String role,
  required String plainPassword,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('saved_userId', userId);
  await prefs.setString('saved_phone', phone);
  await prefs.setString('saved_role', role);
  await _secureStorage.write(key: 'saved_password', value: plainPassword);
}

Future<Map<String, String?>> _loadSaved() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('saved_userId');
  final phone = prefs.getString('saved_phone');
  final role = prefs.getString('saved_role');
  final pwd = await _secureStorage.read(key: 'saved_password');
  return {'userId': userId, 'phone': phone, 'role': role, 'password': pwd};
}

Future<void> _clearSaved() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('saved_userId');
  await prefs.remove('saved_phone');
  await prefs.remove('saved_role');
  await _secureStorage.delete(key: 'saved_password');
}

// App Theme & Colors
class AppColors {
  static const Color primary = Color(0xFF9C6BD6);
  static const Color primaryLight = Color(0xFFB89CE6);
  static const Color primaryDark = Color(0xFF7E57C2);
  static const Color secondary = Color(0xFFE6D6FF);
  static const Color accent = Color(0xFFFFC2D9);
  static const Color background = Color(0xFFFAF7FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2D1B69);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9C6BD6), Color(0xFF7E57C2)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFAF7FF), Color(0xFFF3E8FF)],
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        background: AppColors.background,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSecondary: AppColors.textPrimary,
        onBackground: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        centerTitle: true,
      ),

      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
      ),
      fontFamily: 'Inter',
    );
  }
}

class DropLockApp extends StatelessWidget {
  const DropLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drop Lock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/forgot': (_) => const ForgotPasswordScreen(),
      },
    );
  }
}

// Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _attemptAutoLogin();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _attemptAutoLogin() async {
    final saved = await _loadSaved();
    final userId = saved['userId'];
    await Future.delayed(const Duration(milliseconds: 2500));

    if (userId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (doc.exists) {
          final user = doc.data()!;
          _goToDashboard(user['role'] ?? 'User', user);
          return;
        }
      } catch (_) {}
    }
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _goToDashboard(String role, Map<String, dynamic> user) {
    Widget page;
    switch (role) {
      case 'Rider':
        page = RiderDashboard(user: user);
        break;
      default:
        page = UserDashboard(user: user);
    }
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF9C6BD6).withOpacity(0.9),
              const Color(0xFF7E57C2).withOpacity(0.9),
              const Color(0xFF5E35B1).withOpacity(0.9),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated floating shapes
            Positioned(
              top: -50,
              left: -50,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -80,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated logo container
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_outlined,
                          size: 80,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: Colors.black26,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 50),

                    // App name with glow effect
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: [Colors.white, Colors.white.withOpacity(0.8)],
                        ).createShader(bounds);
                      },
                      child: const Text(
                        'DROP LOCK',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          height: 1.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tagline
                    const Text(
                      'Secure Parcel Delivery',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white70,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 100),

                    // Loading indicator with pulse effect
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Initializing Secure System...',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom decorative elements
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Version 2.0.0 • Secure • Fast • Reliable',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced Login Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  String? selectedRole;
  bool loading = false;
  String? error;
  bool _obscurePassword = true;

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _prefill();
  }

  @override
  void dispose() {
    _controller.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final saved = await _loadSaved();
    setState(() {
      phoneController.text = saved['phone'] ?? '';
      passwordController.text = saved['password'] ?? '';
      selectedRole = saved['role'];
    });
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
      error = null;
    });
    final phone = phoneController.text.trim();
    final pwd = passwordController.text.trim();
    final role = selectedRole;
    if ([phone, pwd].any((s) => s.isEmpty) || role == null) {
      setState(() {
        loading = false;
        error = 'Please fill all fields';
      });
      return;
    }

    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (q.docs.isEmpty) {
        setState(() {
          error = 'No account found for this phone';
          loading = false;
        });
        return;
      }
      final doc = q.docs.first;
      final user = doc.data();
      final storedHash = user['password'] ?? '';
      final hashed = sha256.convert(utf8.encode(pwd)).toString();
      if (storedHash != hashed) {
        setState(() {
          error = 'Invalid credentials';
          loading = false;
        });
        return;
      }

      await _saveLogin(
        userId: doc.id,
        phone: phone,
        role: role,
        plainPassword: pwd,
      );

      Widget page;
      switch (role) {
        case 'Rider':
          page = RiderDashboard(user: user);
          break;
        default:
          page = UserDashboard(user: user);
      }
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      );
    } catch (e) {
      setState(() {
        error = 'Error: $e';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Header
                  Container(
                    height: size.height * 0.32,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.lock_outlined,
                              size: 64,
                              color: Colors.white,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Welcome Back',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Sign in to continue',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Form
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                _buildInputField(
                                  'Phone Number',
                                  phoneController,
                                  Icons.phone_rounded,
                                  TextInputType.phone,
                                ),
                                const SizedBox(height: 16),
                                _buildPasswordField(),
                                const SizedBox(height: 16),
                                _buildRoleDropdown(),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        if (error != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              error!,
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/signup'),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('Create Account'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/forgot'),
                              child: const Text('Forgot Password?'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'Drop Lock v2.0 • Secure Delivery System',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon,
    TextInputType keyboardType,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.background,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.primary),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.background,
      ),
      child: TextField(
        controller: passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: 'Password',
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            color: AppColors.primary,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.background,
      ),
      child: DropdownButtonFormField<String>(
        value: selectedRole,
        decoration: InputDecoration(
          labelText: 'Role',
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: Icon(
            Icons.person_outline_rounded,
            color: AppColors.primary,
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
        ),
        items: const [
          DropdownMenuItem(
            value: 'User',
            child: Text(
              'User',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
          ),
          DropdownMenuItem(
            value: 'Rider',
            child: Text(
              'Rider',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
          ),
        ],
        onChanged: (value) => setState(() => selectedRole = value),
        dropdownColor: Colors.white,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        icon: Icon(
          Icons.arrow_drop_down_rounded,
          color: AppColors.primary,
          size: 28,
        ),
      ),
    );
  }
}

// User Dashboard
class UserDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserDashboard({super.key, required this.user});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _unreadNotifications = 0;
  late final StreamSubscription<QuerySnapshot> _parcelListener;
  final Set<String> _seenParcelIds = {};

  @override
  void initState() {
    super.initState();
    _startParcelListener();
  }

  void _startParcelListener() {
    final phone = widget.user['phone'];
    if (phone != null) {
      _parcelListener = FirebaseFirestore.instance
          .collection('parcels')
          .where('receiverPhone', isEqualTo: phone)
          .snapshots()
          .listen((snapshot) {
            int unreadCount = 0;
            final newParcels = <Map<String, dynamic>>[];

            for (final doc in snapshot.docChanges) {
              final data = doc.doc.data() as Map<String, dynamic>?;
              if (data == null) continue;

              final parcelId = data['parcelId'] ?? doc.doc.id;
              final status = data['status'] ?? '';
              final isViewed = data['isViewed'] ?? false;

              if (!isViewed && status != 'Delivered') {
                unreadCount++;
              }

              // Check if status changed to Delivered
              final isStatusChange = doc.type == DocumentChangeType.modified;
              if (isStatusChange &&
                  status == 'Delivered' &&
                  !_seenParcelIds.contains('delivered_$parcelId')) {
                _seenParcelIds.add('delivered_$parcelId');
                _showParcelDeliveredPopup(data);
              }

              final isNewParcel = doc.type == DocumentChangeType.added;
              if (isNewParcel &&
                  !_seenParcelIds.contains(parcelId) &&
                  status != 'Delivered') {
                _seenParcelIds.add(parcelId);
                newParcels.add(data);
              }
            }

            for (final parcel in newParcels) {
              _showNewParcelPopup(parcel);
            }

            if (mounted) {
              setState(() {
                _unreadNotifications = unreadCount;
              });
            }
          });
    } else {
      _parcelListener = const Stream<QuerySnapshot>.empty().listen((_) {});
    }
  }

  void _clearNotificationBadges() {
    if (mounted) {
      setState(() {
        _unreadNotifications = 0;
      });
    }
  }

  Future<void> _showParcelDeliveredPopup(
    Map<String, dynamic> parcelData,
  ) async {
    if (!mounted) return;

    final senderName = parcelData['senderName'] ?? 'Sender';
    final parcelId = parcelData['parcelId'] ?? '';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '🎉 Parcel Delivered!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your parcel from $senderName has been successfully delivered!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'ID: ${parcelId.substring(0, 8).toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Monospace',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ParcelDetailScreen(parcel: parcelData),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_rounded, size: 20),
                  label: const Text(
                    'View Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Show toast notification
    Fluttertoast.showToast(
      msg: '📦 Your parcel has been delivered!',
      backgroundColor: AppColors.success,
      textColor: Colors.white,
      fontSize: 16,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  Future<void> _showNewParcelPopup(Map<String, dynamic> parcelData) async {
    if (!mounted) return;

    final senderName = parcelData['senderName'] ?? 'Sender';
    final details = parcelData['details'] ?? '';
    final parcelId = parcelData['parcelId'] ?? '';
    final status = parcelData['status'] ?? 'Pending';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inbox_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '📦 New Parcel Assigned',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPopupInfo('From', senderName),
                    const SizedBox(height: 8),
                    _buildPopupInfo('Status', status),
                    const SizedBox(height: 8),
                    _buildPopupInfo(
                      'Parcel ID',
                      '${parcelId.substring(0, 8)}...',
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildPopupInfo('Details', details),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: AppColors.textSecondary.withOpacity(0.3),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ParcelDetailScreen(parcel: parcelData),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('View Details'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupInfo(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Expanded(
          child: Text(value, style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Widget page, {
    Color iconBg = AppColors.primary,
    int? notificationCount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon with badge
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: iconBg.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: iconBg, size: 28),
                    ),
                    if (notificationCount != null && notificationCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            notificationCount > 9
                                ? '9+'
                                : notificationCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (notificationCount != null &&
                              notificationCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                notificationCount.toString(),
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textSecondary.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _parcelListener.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.user['name'] ?? 'User';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // User Avatar
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            userInitial,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Notification Bell
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserNotificationsScreen(
                                    user: widget.user,
                                    onNotificationsViewed:
                                        _clearNotificationBadges,
                                  ),
                                ),
                              );
                            },
                            icon: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          if (_unreadNotifications > 0)
                            Positioned(
                              right: 12,
                              top: 12,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  _unreadNotifications > 9
                                      ? '9+'
                                      : _unreadNotifications.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Parcels',
                          '12',
                          Icons.inbox_rounded,
                          AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'In Transit',
                          '3',
                          Icons.local_shipping_rounded,
                          AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Delivered',
                          '9',
                          Icons.check_circle_rounded,
                          AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildMenuItem(
                        context,
                        'Submit a Parcel',
                        'Send a new parcel for delivery',
                        Icons.add_box_rounded,
                        SubmitOrderScreen(user: widget.user),
                        iconBg: AppColors.primary,
                      ),
                      _buildMenuItem(
                        context,
                        'Incoming Parcels',
                        'View parcels sent to you',
                        Icons.inbox_rounded,
                        IncomingParcelsScreen(user: widget.user),
                        notificationCount: _unreadNotifications,
                        iconBg: AppColors.info,
                      ),
                      _buildMenuItem(
                        context,
                        'Track Parcel',
                        'Real-time parcel tracking',
                        Icons.map_rounded,
                        UserTrackScreen(user: widget.user),
                        iconBg: AppColors.warning,
                      ),
                      _buildMenuItem(
                        context,
                        'Parcel Status',
                        'Check status of your parcels',
                        Icons.search_rounded,
                        CheckingOrderStatusScreen(user: widget.user),
                        iconBg: AppColors.error,
                      ),
                      _buildMenuItem(
                        context,
                        'Parcel History',
                        'View your delivery history',
                        Icons.history_rounded,
                        ParcelHistoryScreen(user: widget.user),
                        iconBg: AppColors.success,
                      ),
                      _buildMenuItem(
                        context,
                        'My Profile',
                        'Manage your account',
                        Icons.person_rounded,
                        ProfileScreen(user: widget.user),
                        iconBg: AppColors.primaryLight,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Logout Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                onPressed: () => logout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'Log Out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

//   Enhanced Submit Order Screen
class SubmitOrderScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const SubmitOrderScreen({super.key, required this.user});

  @override
  State<SubmitOrderScreen> createState() => _SubmitOrderScreenState();
}

class _SubmitOrderScreenState extends State<SubmitOrderScreen> {
  final TextEditingController senderName = TextEditingController();
  final TextEditingController senderPhone = TextEditingController();
  final TextEditingController senderAddress = TextEditingController();
  final TextEditingController receiverName = TextEditingController();
  final TextEditingController receiverPhone = TextEditingController();
  final TextEditingController receiverAddress = TextEditingController();
  final TextEditingController parcelDetails = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    senderName.text = widget.user['name'] ?? '';
    senderPhone.text = widget.user['phone'] ?? '';
    senderAddress.text = widget.user['senderAddress'] ?? '';
  }

  @override
  void dispose() {
    senderName.dispose();
    senderPhone.dispose();
    senderAddress.dispose();
    receiverName.dispose();
    receiverPhone.dispose();
    receiverAddress.dispose();
    parcelDetails.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Parcel'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.local_shipping_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send Parcel',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Fill in the details to send a parcel',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Sender Information Card
                _buildSectionCard(
                  'Sender Information',
                  Icons.person_outline_rounded,
                  [
                    _buildTextField(
                      'Sender Name',
                      senderName,
                      Icons.person_rounded,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Sender Phone',
                      senderPhone,
                      Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Sender Address',
                      senderAddress,
                      Icons.location_on_rounded,
                      maxLines: 2,
                      isRequired: true,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Receiver Information Card
                _buildSectionCard(
                  'Receiver Information',
                  Icons.person_rounded,
                  [
                    _buildTextField(
                      'Receiver Name',
                      receiverName,
                      Icons.person_rounded,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Receiver Phone',
                      receiverPhone,
                      Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Receiver Address',
                      receiverAddress,
                      Icons.location_on_rounded,
                      maxLines: 2,
                      isRequired: true,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Parcel Details Card
                _buildSectionCard('Parcel Details', Icons.inventory_2_rounded, [
                  _buildTextField(
                    'Parcel Description',
                    parcelDetails,
                    Icons.description_rounded,
                    maxLines: 3,
                    isRequired: true,
                  ),
                ]),

                const SizedBox(height: 40),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitParcel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 40,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      shadowColor: AppColors.primary.withOpacity(0.4),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.qr_code_2_rounded, size: 24),
                    label: Text(
                      _isSubmitting ? 'Processing...' : 'Submit & Generate QR',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.background,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: isRequired
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter $label';
                }
                return null;
              }
            : null,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: '$label${isRequired ? ' *' : ''}',
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.primary),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: maxLines > 1 ? 16 : 0,
          ),
        ),
      ),
    );
  }

  Future<void> _submitParcel() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        final parcelId = const Uuid().v4();

        // Generate 4-digit password
        final random = Random();
        final pickupPassword = (1000 + random.nextInt(9000))
            .toString(); // Generates 1000-9999

        final qrData = jsonEncode({
          'parcelId': parcelId,
          'senderName': senderName.text.trim(),
          'senderPhone': senderPhone.text.trim(),
          'receiverName': receiverName.text.trim(),
          'receiverPhone': receiverPhone.text.trim(),
          'status': 'Pending',
          'type': 'parcel',
        });

        final parcelData = {
          'senderId': widget.user['phone'],
          'senderName': senderName.text.trim(),
          'senderPhone': senderPhone.text.trim(),
          'senderAddress': senderAddress.text.trim(),
          'receiverName': receiverName.text.trim(),
          'receiverPhone': receiverPhone.text.trim(),
          'receiverAddress': receiverAddress.text.trim(),
          'details': parcelDetails.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'parcelId': parcelId,
          'status': 'Pending',
          'isViewed': false,
          'riderId': null,
          'riderName': null,
          'qrData': qrData,
          'qrGenerated': true,
          'pickupPassword': pickupPassword,
        };

        // Get current location
        Position? currentPosition;
        try {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            currentPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
          }
        } catch (e) {
          debugPrint('Error getting location: $e');
        }

        // Save to Firestore
        await FirebaseFirestore.instance
            .collection('parcels')
            .doc(parcelId)
            .set(parcelData);

        // Save password and location to Realtime Database
        final DatabaseReference realtimeDb = FirebaseDatabase.instance.ref();
        await realtimeDb.child('passwords').set({'password': pickupPassword});

        if (currentPosition != null) {
          await realtimeDb.child('locations').set({
            'lat': currentPosition.latitude,
            'long': currentPosition.longitude,
          });
        }

        await _showQRDialog(qrData, parcelId, pickupPassword);

        receiverName.clear();
        receiverPhone.clear();
        receiverAddress.clear();
        parcelDetails.clear();

        Fluttertoast.showToast(
          msg: 'Parcel submitted successfully!',
          backgroundColor: AppColors.success,
          textColor: Colors.white,
          fontSize: 16,
          gravity: ToastGravity.BOTTOM,
        );
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Error submitting parcel: $e',
          backgroundColor: AppColors.error,
          textColor: Colors.white,
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showQRDialog(
    String data,
    String parcelId,
    String pickupPassword,
  ) async {
    final qrBytes = await _generateQRBytes(data);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'QR Code Generated!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Show this code to the rider',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Image.memory(qrBytes, width: 200, height: 200),
                ),
                const SizedBox(height: 20),
                Text(
                  'Parcel ID: ${parcelId.substring(0, 8)}...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Monospace',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Pickup Password',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pickupPassword,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 6,
                          fontFamily: 'Monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generateQRBytes(String data) async {
    final qr = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      color: Colors.black,
      emptyColor: Colors.white,
    );
    final picData = await qr.toImageData(300, format: ui.ImageByteFormat.png);
    return picData!.buffer.asUint8List();
  }
}

// Rider Dashboard
class RiderDashboard extends StatelessWidget {
  final Map<String, dynamic> user;
  const RiderDashboard({super.key, required this.user});

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Widget page,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textSecondary.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riderName = user['name'] ?? 'Rider';
    final riderInitial = riderName.isNotEmpty
        ? riderName[0].toUpperCase()
        : 'R';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            riderInitial,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello,',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            Text(
                              riderName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delivery_dining_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRiderStatCard(
                          'Active',
                          '5',
                          Icons.local_shipping_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildRiderStatCard(
                          'Today',
                          '12',
                          Icons.today_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildRiderStatCard(
                          'Rating',
                          '4.8',
                          Icons.star_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildMenuItem(
                        context,
                        'Available Parcels',
                        'Accept new delivery requests',
                        Icons.local_shipping_rounded,
                        RiderAvailableParcelsScreen(user: user),
                        AppColors.primary,
                      ),
                      _buildMenuItem(
                        context,
                        'My Deliveries',
                        'View assigned deliveries',
                        Icons.assignment_rounded,
                        RiderAssignedDeliveriesScreen(user: user),
                        AppColors.info,
                      ),
                      _buildMenuItem(
                        context,
                        'Scan QR Code',
                        'Scan to pickup/deliver',
                        Icons.qr_code_scanner_rounded,
                        RiderScanParcelScreen(user: user),
                        AppColors.warning,
                      ),
                      _buildMenuItem(
                        context,
                        'Delivery History',
                        'Past delivery records',
                        Icons.history_rounded,
                        RiderDeliveryHistoryScreen(user: user),
                        AppColors.success,
                      ),
                      _buildMenuItem(
                        context,
                        'My Profile',
                        'Manage rider profile',
                        Icons.person_rounded,
                        ProfileScreen(user: user),
                        AppColors.primaryLight,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Logout Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                onPressed: () => logout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'Log Out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Profile Screen
class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    _nameController.text = widget.user['name'] ?? '';
    _phoneController.text = widget.user['phone'] ?? '';
    _emailController.text = widget.user['email'] ?? '';
    _addressController.text = widget.user['senderAddress'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.user['name'] ?? 'User';
    final userRole = widget.user['role'] ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Profile Header
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        userRole,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Profile Form
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildProfileField(
                        'Full Name',
                        _nameController,
                        Icons.person_rounded,
                        enabled: _isEditing,
                      ),
                      const SizedBox(height: 20),
                      _buildProfileField(
                        'Phone Number',
                        _phoneController,
                        Icons.phone_rounded,
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 20),
                      _buildProfileField(
                        'Email Address',
                        _emailController,
                        Icons.email_rounded,
                        enabled: _isEditing,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      _buildProfileField(
                        'Address',
                        _addressController,
                        Icons.location_on_rounded,
                        enabled: _isEditing,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),

              if (_isEditing) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _loadUserData();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: AppColors.textSecondary.withOpacity(0.3),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 30),

              // Account Information
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildInfoItem('User ID', widget.user['userId'] ?? 'N/A'),
                      const Divider(height: 32),
                      _buildInfoItem(
                        'Phone Number',
                        widget.user['phone'] ?? 'N/A',
                      ),
                      const Divider(height: 32),
                      _buildInfoItem('Role', userRole),
                      const Divider(height: 32),
                      _buildInfoItem(
                        'Member Since',
                        _formatMemberSince(widget.user['createdAt']),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Change Password Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _changePassword,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  icon: const Icon(Icons.lock_reset_rounded, size: 20),
                  label: const Text(
                    'Change Password',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.background,
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 16,
          color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.primary),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: maxLines > 1 ? 16 : 0,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Row(
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatMemberSince(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      Fluttertoast.showToast(msg: 'Name and phone are required');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        Fluttertoast.showToast(msg: 'User not found');
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'senderAddress': _addressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_phone', _phoneController.text.trim());

      setState(() {
        _isEditing = false;
      });

      Fluttertoast.showToast(
        msg: 'Profile updated successfully!',
        backgroundColor: AppColors.success,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error updating profile: $e',
        backgroundColor: AppColors.error,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _getCurrentUserId() async {
    final saved = await _loadSaved();
    return saved['userId'];
  }

  Future<void> _changePassword() async {
    final currentPassword = await _showPasswordDialog('Enter current password');
    if (currentPassword == null) return;

    final newPassword = await _showPasswordDialog('Enter new password');
    if (newPassword == null) return;

    final confirmPassword = await _showPasswordDialog('Confirm new password');
    if (confirmPassword == null) return;

    if (newPassword != confirmPassword) {
      Fluttertoast.showToast(msg: 'Passwords do not match');
      return;
    }

    if (newPassword.length < 6) {
      Fluttertoast.showToast(msg: 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        Fluttertoast.showToast(msg: 'User not found');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final storedHash = userDoc.data()?['password'] ?? '';
      final currentHash = sha256
          .convert(utf8.encode(currentPassword))
          .toString();

      if (storedHash != currentHash) {
        Fluttertoast.showToast(msg: 'Current password is incorrect');
        return;
      }

      final newHash = sha256.convert(utf8.encode(newPassword)).toString();
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'password': newHash,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _secureStorage.write(key: 'saved_password', value: newPassword);

      Fluttertoast.showToast(
        msg: 'Password changed successfully!',
        backgroundColor: AppColors.success,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error changing password: $e',
        backgroundColor: AppColors.error,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _showPasswordDialog(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.background,
                ),
                child: TextField(
                  controller: controller,
                  obscureText: true,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//Logout helper
void logout(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Log Out',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Are you sure you want to log out?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _clearSaved();
                      Navigator.pushAndRemoveUntil(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 600),
                          pageBuilder: (_, __, ___) => const LoginScreen(),
                          transitionsBuilder: (_, animation, __, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Log Out'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// IncomingParcelsScreen,

class IncomingParcelsScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const IncomingParcelsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final phone = user['phone'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Parcels'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('parcels')
              .where('receiverPhone', isEqualTo: phone)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            final active = docs.where((d) {
              final m = d.data() as Map<String, dynamic>;
              final status = m['status'] ?? '';
              return status != 'Delivered';
            }).toList();

            if (active.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 80,
                      color: AppColors.textSecondary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No incoming parcels',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Parcels sent to you will appear here',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: active.length,
              itemBuilder: (context, i) {
                final data = active[i].data() as Map<String, dynamic>;
                final parcelId = data['parcelId'] ?? active[i].id;
                final status = data['status'] ?? 'Pending';
                final senderName = data['senderName'] ?? 'Unknown';
                final details = data['details'] ?? '';
                final createdAt = data['createdAt'] as Timestamp?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getStatusIcon(status),
                              color: _getStatusColor(status),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  senderName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  details.isNotEmpty && details.length > 50
                                      ? '${details.substring(0, 50)}...'
                                      : details,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          status,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _getStatusColor(status),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      createdAt != null
                                          ? _formatDate(createdAt.toDate())
                                          : '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ParcelDetailScreen(parcel: data),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('View'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Delivered':
        return AppColors.success;
      case 'Picked Up':
      case 'Out for Delivery':
        return AppColors.info;
      case 'Assigned':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Delivered':
        return Icons.check_circle_rounded;
      case 'Picked Up':
        return Icons.inventory_2_rounded;
      case 'Out for Delivery':
        return Icons.local_shipping_rounded;
      case 'Assigned':
        return Icons.assignment_rounded;
      default:
        return Icons.pending_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

// Parcel Detail Screen
class ParcelDetailScreen extends StatelessWidget {
  final Map<String, dynamic> parcel;
  const ParcelDetailScreen({super.key, required this.parcel});

  @override
  Widget build(BuildContext context) {
    final senderName = parcel['senderName'] ?? 'Not available';
    final senderPhone = parcel['senderPhone'] ?? 'Not available';
    final senderAddress = parcel['senderAddress'] ?? 'Not available';
    final receiverName = parcel['receiverName'] ?? 'Not available';
    final receiverPhone = parcel['receiverPhone'] ?? 'Not available';
    final receiverAddress = parcel['receiverAddress'] ?? 'Not available';
    final details = parcel['details'] ?? 'No details provided';
    final status = parcel['status'] ?? 'Pending';
    final parcelId = parcel['parcelId'] ?? 'Unknown ID';
    final createdAt = parcel['createdAt'] as Timestamp?;
    final riderName = parcel['riderName'];
    final pickupPassword = parcel['pickupPassword'] ?? 'N/A';

    // Mark as viewed when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (parcel['isViewed'] == false) {
        FirebaseFirestore.instance.collection('parcels').doc(parcelId).update({
          'isViewed': true,
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcel Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              _getStatusIcon(status),
                              color: _getStatusColor(status),
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Parcel #${parcelId.substring(0, 8).toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      status,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _getStatusColor(status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (riderName != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.delivery_dining_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Assigned Rider',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      riderName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Sender Information
              _buildDetailCard(
                'Sender Information',
                Icons.person_outline_rounded,
                [
                  _buildDetailRow('Name', senderName),
                  _buildDetailRow('Phone', senderPhone),
                  _buildDetailRow('Address', senderAddress),
                ],
              ),

              const SizedBox(height: 16),

              // Receiver Information
              _buildDetailCard('Receiver Information', Icons.person_rounded, [
                _buildDetailRow('Name', receiverName),
                _buildDetailRow('Phone', receiverPhone),
                _buildDetailRow('Address', receiverAddress),
              ]),

              const SizedBox(height: 16),

              // Parcel Details
              _buildDetailCard('Parcel Details', Icons.description_rounded, [
                _buildDetailRow('Description', details),
                if (createdAt != null)
                  _buildDetailRow(
                    'Created',
                    '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}',
                  ),
              ]),

              const SizedBox(height: 16),

              // Pickup Password Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                color: AppColors.secondary,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Pickup Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            pickupPassword,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: 8,
                              fontFamily: 'Monospace',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Keep this password secure. Only share between sender and receiver.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Actions
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Fluttertoast.showToast(
                      msg: 'Parcel acknowledged',
                      backgroundColor: AppColors.success,
                    );
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text(
                    'Acknowledge Receipt',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Delivered':
        return AppColors.success;
      case 'Picked Up':
      case 'Out for Delivery':
        return AppColors.info;
      case 'Assigned':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Delivered':
        return Icons.check_circle_rounded;
      case 'Picked Up':
        return Icons.inventory_2_rounded;
      case 'Out for Delivery':
        return Icons.local_shipping_rounded;
      case 'Assigned':
        return Icons.assignment_rounded;
      default:
        return Icons.pending_rounded;
    }
  }
}

// User Track Screen with Google Maps
class UserTrackScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserTrackScreen({super.key, required this.user});

  @override
  State<UserTrackScreen> createState() => _UserTrackScreenState();
}

class _UserTrackScreenState extends State<UserTrackScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  String? _errorMessage;
  String? _trackingParcelId;
  Map<String, Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _parcelIcon;
  BitmapDescriptor? _userIcon;
  LatLng? _parcelLocation;
  LatLng? _userLocation;
  StreamSubscription<QuerySnapshot>? _parcelListener;
  StreamSubscription<DatabaseEvent>? _locationListener;

  // Mock delivery path (in real app, this would come from Firestore)
  final List<LatLng> _deliveryPath = [];

  @override
  void initState() {
    super.initState();
    _loadLocationFromRealtimeDatabase();
    _startRealtimeLocationListener();
    _loadCustomMapIcons();
    _startTrackingIfNeeded();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _parcelListener?.cancel();
    _locationListener?.cancel();
    super.dispose();
  }

  void _startRealtimeLocationListener() {
    final DatabaseReference locationRef = FirebaseDatabase.instance.ref().child(
      'locations',
    );

    _locationListener = locationRef.onValue.listen((DatabaseEvent event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final lat = data['lat'] as double?;
        final long = data['long'] as double?;

        if (lat != null && long != null) {
          final newLocation = LatLng(lat, long);

          if (mounted) {
            setState(() {
              _parcelLocation = newLocation;
              _userLocation = newLocation;
              _isLoading = false;
            });

            // Update marker at the new location
            _addParcelMarker(newLocation, 'location', 'Parcel Location');

            // Animate camera to new location
            _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: newLocation, zoom: 14.0),
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _loadLocationFromRealtimeDatabase() async {
    try {
      final DatabaseReference realtimeDb = FirebaseDatabase.instance.ref();
      final snapshot = await realtimeDb.child('locations').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final lat = data['lat'] as double?;
        final long = data['long'] as double?;

        if (lat != null && long != null) {
          setState(() {
            _parcelLocation = LatLng(lat, long);
            _userLocation = LatLng(lat, long);
            _isLoading = false;
          });

          // Add marker at the location
          _addParcelMarker(_parcelLocation!, 'location', 'Parcel Location');
        } else {
          setState(() {
            _errorMessage = 'Location coordinates not found';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'No location data available';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCustomMapIcons() async {
    try {
      // You can load custom icons for parcel and user
      // For now, we'll use default markers
      _parcelIcon = await BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueBlue,
      );
      _userIcon = await BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      );
    } catch (e) {
      // Use default markers if custom loading fails
      _parcelIcon = BitmapDescriptor.defaultMarker;
      _userIcon = BitmapDescriptor.defaultMarker;
    }
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _errorMessage = 'Location services are disabled. Please enable them.';
        _isLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'Location permissions are denied';
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _errorMessage =
            'Location permissions are permanently denied. Please enable them in app settings.';
        _isLoading = false;
      });
      return;
    }

    // Get current position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      // Add user marker
      _addUserMarker();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  void _addUserMarker() {
    if (_userLocation != null) {
      setState(() {
        _markers['user'] = Marker(
          markerId: const MarkerId('user_location'),
          position: _userLocation!,
          icon: _userIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Your current position',
          ),
          anchor: const Offset(0.5, 0.5),
        );
      });
    }
  }

  void _addParcelMarker(LatLng position, String parcelId, String status) {
    String statusText = '';
    Color markerColor = Colors.blue;

    switch (status) {
      case 'Picked Up':
        statusText = 'Parcel Picked Up';
        markerColor = Colors.orange;
        break;
      case 'Out for Delivery':
        statusText = 'Out for Delivery';
        markerColor = Colors.purple;
        break;
      case 'Delivered':
        statusText = 'Delivered';
        markerColor = Colors.green;
        break;
      default:
        statusText = 'In Transit';
        markerColor = Colors.blue;
    }

    setState(() {
      _markers['parcel'] = Marker(
        markerId: MarkerId('parcel_$parcelId'),
        position: position,
        icon:
            _parcelIcon ??
            BitmapDescriptor.defaultMarkerWithHue(
              _getMarkerHueForStatus(status),
            ),
        infoWindow: InfoWindow(
          title: 'Parcel #${parcelId.substring(0, 8)}',
          snippet: statusText,
        ),
        anchor: const Offset(0.5, 0.5),
      );
    });
  }

  double _getMarkerHueForStatus(String status) {
    switch (status) {
      case 'Picked Up':
        return BitmapDescriptor.hueOrange;
      case 'Out for Delivery':
        return BitmapDescriptor.hueViolet;
      case 'Delivered':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueBlue;
    }
  }

  void _startTrackingIfNeeded() {
    // Listen for incoming parcels that might need tracking
    final phone = widget.user['phone'];
    if (phone != null) {
      _parcelListener = FirebaseFirestore.instance
          .collection('parcels')
          .where('receiverPhone', isEqualTo: phone)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              final doc = snapshot.docs.first;
              final data = doc.data();
              final parcelId = data['parcelId'] ?? doc.id;
              final status = data['status'] ?? '';

              if (status == 'Picked Up' || status == 'Out for Delivery') {
                _startTrackingParcel(parcelId, data);
              } else if (status == 'Delivered' &&
                  _trackingParcelId == parcelId) {
                // Stop tracking when delivered
                _stopTracking();
                _showDeliveryCompleteNotification(data);
              }
            } else if (_trackingParcelId != null) {
              // No active parcels, stop tracking
              _stopTracking();
            }
          });
    }
  }

  void _stopTracking() {
    if (mounted) {
      setState(() {
        _trackingParcelId = null;
        _markers.clear();
        _polylines.clear();
        _parcelLocation = null;
      });
    }
  }

  void _showDeliveryCompleteNotification(Map<String, dynamic> parcelData) {
    if (!mounted) return;

    final parcelId = parcelData['parcelId'] ?? '';

    Fluttertoast.showToast(
      msg: '✅ Parcel delivered! Tracking stopped.',
      backgroundColor: AppColors.success,
      textColor: Colors.white,
      fontSize: 16,
      toastLength: Toast.LENGTH_LONG,
    );

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delivery Complete!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your parcel has been successfully delivered. Tracking has been stopped.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Parcel #${parcelId.substring(0, 8).toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Monospace',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ParcelDetailScreen(parcel: parcelData),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text(
                    'View Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startTrackingParcel(String parcelId, Map<String, dynamic> parcelData) {
    setState(() {
      _trackingParcelId = parcelId;
    });

    // In a real app, you would get the rider's location from Firestore
    // For now, we'll simulate a moving parcel
    _simulateParcelMovement(parcelData);
  }

  void _simulateParcelMovement(Map<String, dynamic> parcelData) async {
    // Start from a random location near the user
    if (_userLocation == null) return;

    // Generate a starting point near user (simulated)
    final startLat = _userLocation!.latitude + 0.01;
    final startLng = _userLocation!.longitude + 0.01;
    _parcelLocation = LatLng(startLat, startLng);

    // Add initial parcel marker
    _addParcelMarker(
      _parcelLocation!,
      parcelData['parcelId'] ?? 'unknown',
      parcelData['status'] ?? 'Out for Delivery',
    );

    // Create a polyline from parcel to user
    _createPolyline(_parcelLocation!, _userLocation!);

    // Animate the parcel moving towards user
    _animateParcelToUser();
  }

  void _createPolyline(LatLng from, LatLng to) {
    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_path'),
          color: AppColors.primary,
          width: 4,
          points: [from, to],
          geodesic: true,
          patterns: [PatternItem.dash(10), PatternItem.gap(5)],
        ),
      );
    });
  }

  void _animateParcelToUser() async {
    if (_parcelLocation == null || _userLocation == null) return;

    const totalSteps = 50;
    const duration = Duration(seconds: 30);

    final latStep =
        (_userLocation!.latitude - _parcelLocation!.latitude) / totalSteps;
    final lngStep =
        (_userLocation!.longitude - _parcelLocation!.longitude) / totalSteps;

    for (int i = 0; i <= totalSteps; i++) {
      await Future.delayed(duration ~/ totalSteps);

      if (!mounted) return;

      final newLat = _parcelLocation!.latitude + (latStep * i);
      final newLng = _parcelLocation!.longitude + (lngStep * i);
      final newPosition = LatLng(newLat, newLng);

      setState(() {
        _parcelLocation = newPosition;

        // Update parcel marker
        if (_markers.containsKey('parcel') && _trackingParcelId != null) {
          _markers['parcel'] = _markers['parcel']!.copyWith(
            positionParam: newPosition,
          );
        }

        // Update polyline
        _polylines = {
          Polyline(
            polylineId: const PolylineId('delivery_path'),
            color: AppColors.primary.withOpacity(0.7),
            width: 4,
            points: [newPosition, _userLocation!],
            geodesic: true,
            patterns: [PatternItem.dash(10), PatternItem.gap(5)],
          ),
        };
      });

      // Update camera position
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              newLat < _userLocation!.latitude
                  ? newLat
                  : _userLocation!.latitude,
              newLng < _userLocation!.longitude
                  ? newLng
                  : _userLocation!.longitude,
            ),
            northeast: LatLng(
              newLat > _userLocation!.latitude
                  ? newLat
                  : _userLocation!.latitude,
              newLng > _userLocation!.longitude
                  ? newLng
                  : _userLocation!.longitude,
            ),
          ),
          100.0,
        ),
      );
    }
  }

  Widget _buildMap() {
    final initialPosition =
        _userLocation ??
        const LatLng(37.422, -122.084); // Default to Googleplex

    return GoogleMap(
      onMapCreated: (controller) {
        setState(() {
          _mapController = controller;
        });

        // Zoom to show both markers if available
        if (_userLocation != null && _parcelLocation != null) {
          controller.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(
                  _userLocation!.latitude < _parcelLocation!.latitude
                      ? _userLocation!.latitude
                      : _parcelLocation!.latitude,
                  _userLocation!.longitude < _parcelLocation!.longitude
                      ? _userLocation!.longitude
                      : _parcelLocation!.longitude,
                ),
                northeast: LatLng(
                  _userLocation!.latitude > _parcelLocation!.latitude
                      ? _userLocation!.latitude
                      : _parcelLocation!.latitude,
                  _userLocation!.longitude > _parcelLocation!.longitude
                      ? _userLocation!.longitude
                      : _parcelLocation!.longitude,
                ),
              ),
              100.0,
            ),
          );
        } else if (_userLocation != null) {
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(_userLocation!, 15.0),
          );
        }
      },
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 14.0,
      ),
      markers: _markers.values.toSet(),
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      compassEnabled: true,
      zoomControlsEnabled: true,
      mapToolbarEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: true,
      trafficEnabled: true,
      buildingsEnabled: true,
    );
  }

  Widget _buildTrackingInfo() {
    if (_trackingParcelId == null) {
      return Container();
    }

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_shipping_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text(
                    'Active Delivery',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusIndicator('Picked Up', _parcelLocation != null),
                  const SizedBox(width: 8),
                  _buildProgressLine(true),
                  const SizedBox(width: 8),
                  _buildStatusIndicator('In Transit', _parcelLocation != null),
                  const SizedBox(width: 8),
                  _buildProgressLine(
                    _parcelLocation != null && _userLocation != null,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusIndicator('Delivered', false),
                ],
              ),
              const SizedBox(height: 16),
              if (_parcelLocation != null && _userLocation != null) ...[
                const Text(
                  'Estimated Delivery Time:',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '10-15 minutes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rider is on the way to your location',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool active) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary
                : AppColors.textSecondary.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? AppColors.primary
                  : AppColors.textSecondary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: active
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? AppColors.primary : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(bool active) {
    return Expanded(
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary
              : AppColors.textSecondary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Future<void> _searchAndTrackParcel(String parcelId) async {
    if (parcelId.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter a parcel ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('parcels')
          .doc(parcelId)
          .get();

      if (!doc.exists) {
        setState(() {
          _errorMessage = 'Parcel not found';
          _isLoading = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? '';
      final receiverPhone = data['receiverPhone'] ?? '';
      final senderPhone = data['senderPhone'] ?? '';
      final currentUserPhone = widget.user['phone'] ?? '';

      // Check if the current user is either the sender or receiver
      if (receiverPhone != currentUserPhone &&
          senderPhone != currentUserPhone) {
        setState(() {
          _errorMessage = 'You are not authorized to track this parcel';
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: 'Access Denied: Only sender and receiver can track this parcel',
          backgroundColor: AppColors.error,
          textColor: Colors.white,
        );
        return;
      }

      if (status != 'Picked Up' && status != 'Out for Delivery') {
        setState(() {
          _errorMessage = 'This parcel is not currently in transit';
          _isLoading = false;
        });
        return;
      }

      // Start tracking the parcel
      _startTrackingParcel(parcelId, data);

      setState(() {
        _isLoading = false;
      });

      Fluttertoast.showToast(
        msg: 'Tracking parcel #${parcelId.substring(0, 8)}',
        backgroundColor: AppColors.success,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error tracking parcel: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Parcel'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_trackingParcelId != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                // Refresh tracking data
                if (_trackingParcelId != null) {
                  _searchAndTrackParcel(_trackingParcelId!);
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading map...',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _requestLocationPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Stack(children: [_buildMap(), _buildTrackingInfo()]),
    );
  }
}

// Checking Order Status Screen
class CheckingOrderStatusScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const CheckingOrderStatusScreen({super.key, required this.user});

  @override
  State<CheckingOrderStatusScreen> createState() =>
      _CheckingOrderStatusScreenState();
}

class _CheckingOrderStatusScreenState extends State<CheckingOrderStatusScreen> {
  final TextEditingController _parcelIdController = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _foundParcel;
  String? _errorMessage;

  @override
  void dispose() {
    _parcelIdController.dispose();
    super.dispose();
  }

  Future<void> _searchParcel() async {
    final parcelId = _parcelIdController.text.trim();

    if (parcelId.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter a parcel ID');
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _foundParcel = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('parcels')
          .doc(parcelId)
          .get();

      if (!doc.exists) {
        setState(() {
          _errorMessage = 'Parcel not found';
          _isSearching = false;
        });
        Fluttertoast.showToast(
          msg: 'Parcel not found',
          backgroundColor: AppColors.error,
        );
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final senderPhone = data['senderPhone'] ?? '';
      final receiverPhone = data['receiverPhone'] ?? '';
      final currentUserPhone = widget.user['phone'] ?? '';

      // Authorization check: Only sender and receiver can check status
      if (senderPhone != currentUserPhone &&
          receiverPhone != currentUserPhone) {
        setState(() {
          _errorMessage =
              'Access Denied: You are not authorized to view this parcel';
          _isSearching = false;
        });
        Fluttertoast.showToast(
          msg:
              'Access Denied: Only sender and receiver can check this parcel status',
          backgroundColor: AppColors.error,
          textColor: Colors.white,
        );
        return;
      }

      setState(() {
        _foundParcel = data;
        _isSearching = false;
      });

      Fluttertoast.showToast(
        msg: 'Parcel found!',
        backgroundColor: AppColors.success,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching parcel: $e';
        _isSearching = false;
      });
      Fluttertoast.showToast(
        msg: 'Error: $e',
        backgroundColor: AppColors.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcel Status'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            // Search Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Check Parcel Status',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your parcel ID to check status',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextField(
                      controller: _parcelIdController,
                      decoration: InputDecoration(
                        hintText: 'Parcel ID or tracking number...',
                        hintStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.qr_code_rounded,
                          color: Colors.white,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => _searchParcel(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSearching ? null : _searchParcel,
                      icon: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: Text(
                        _isSearching ? 'Searching...' : 'Check Status',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Results or Recent Parcels
            Expanded(
              child: _foundParcel != null
                  ? _buildParcelDetails()
                  : _errorMessage != null
                  ? _buildErrorState()
                  : _buildRecentParcels(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParcelDetails() {
    if (_foundParcel == null) return Container();

    final status = _foundParcel!['status'] ?? 'Unknown';
    final senderName = _foundParcel!['senderName'] ?? 'N/A';
    final receiverName = _foundParcel!['receiverName'] ?? 'N/A';
    final details = _foundParcel!['details'] ?? 'No details';
    final parcelId = _foundParcel!['parcelId'] ?? '';
    final createdAt = _foundParcel!['createdAt'] as Timestamp?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Parcel #${parcelId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: AppColors.textSecondary.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.person_outline, 'Sender', senderName),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.person, 'Receiver', receiverName),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.description, 'Details', details),
                  if (createdAt != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.calendar_today,
                      'Created',
                      '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParcelDetailScreen(parcel: _foundParcel!),
                  ),
                );
              },
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('View Full Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _parcelIdController.clear();
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentParcels() {
    final phone = widget.user['phone'];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Recent Parcels',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('parcels')
                  .where('receiverPhone', isEqualTo: phone)
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  // Try sender's parcels
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('parcels')
                        .where('senderPhone', isEqualTo: phone)
                        .orderBy('createdAt', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (context, senderSnapshot) {
                      if (!senderSnapshot.hasData ||
                          senderSnapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }
                      return _buildParcelList(senderSnapshot.data!.docs);
                    },
                  );
                }
                return _buildParcelList(snapshot.data!.docs);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final parcelId = data['parcelId'] ?? docs[index].id;
        final status = data['status'] ?? 'Pending';
        final receiverName = data['receiverName'] ?? 'N/A';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () {
                setState(() {
                  _foundParcel = data;
                  _parcelIdController.text = parcelId;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(status),
                        color: _getStatusColor(status),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parcel #${parcelId.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'To: $receiverName',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 14,
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.textSecondary.withOpacity(0.5),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Parcels Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Enter a parcel ID above to check its status',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Delivered':
        return AppColors.success;
      case 'Picked Up':
      case 'Out for Delivery':
        return AppColors.info;
      case 'Assigned':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Delivered':
        return Icons.check_circle_rounded;
      case 'Picked Up':
        return Icons.inventory_2_rounded;
      case 'Out for Delivery':
        return Icons.local_shipping_rounded;
      case 'Assigned':
        return Icons.assignment_rounded;
      default:
        return Icons.inventory_rounded;
    }
  }
}

// Parcel History Screen
class ParcelHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ParcelHistoryScreen({super.key, required this.user});

  @override
  State<ParcelHistoryScreen> createState() => _ParcelHistoryScreenState();
}

class _ParcelHistoryScreenState extends State<ParcelHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final phone = widget.user['phone'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcel History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('parcels')
              .where('senderPhone', isEqualTo: phone)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading history',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return _buildParcelItem(data);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildParcelItem(Map<String, dynamic> data) {
    final status = data['status'] ?? 'Pending';
    final receiverName = data['receiverName'] ?? 'Receiver';
    final receiverAddress = data['receiverAddress'] ?? '';
    final details = data['details'] ?? 'No details provided';
    final createdAt = data['createdAt'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receiverName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          receiverAddress,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Parcel Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  details,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Status and Date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (createdAt != null)
                    Text(
                      _formatDate(createdAt.toDate()),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'No Parcel History',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Send your first parcel to see it here!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubmitOrderScreen(user: widget.user),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Send First Parcel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Delivered':
        return AppColors.success;
      case 'Picked Up':
        return AppColors.info;
      case 'Assigned':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Delivered':
        return Icons.check_circle_rounded;
      case 'Picked Up':
        return Icons.inventory_2_rounded;
      case 'Assigned':
        return Icons.assignment_rounded;
      default:
        return Icons.pending_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

// User Notifications Screen
class UserNotificationsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onNotificationsViewed;

  const UserNotificationsScreen({
    super.key,
    required this.user,
    this.onNotificationsViewed,
  });

  @override
  State<UserNotificationsScreen> createState() =>
      _UserNotificationsScreenState();
}

class _UserNotificationsScreenState extends State<UserNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onNotificationsViewed?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.user['phone'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('parcels')
              .where('receiverPhone', isEqualTo: phone)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading notifications',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            final notificationParcels = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? '';
              return status != 'Delivered';
            }).toList();

            if (notificationParcels.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_off_rounded,
                        size: 80,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'All Caught Up!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'No new notifications. New parcel assignments will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: notificationParcels.length,
              itemBuilder: (context, i) {
                final doc = notificationParcels[i];
                final data = doc.data() as Map<String, dynamic>;
                final parcelId = data['parcelId'] ?? doc.id;
                final status = data['status'] ?? 'Pending';
                final isViewed = data['isViewed'] ?? false;
                final senderName = data['senderName'] ?? 'Sender';
                final details = data['details'] ?? 'No details';
                final createdAt = data['createdAt'] as Timestamp?;
                final riderName = data['riderName'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    color: isViewed ? Colors.white : AppColors.secondary,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        if (!isViewed) {
                          FirebaseFirestore.instance
                              .collection('parcels')
                              .doc(parcelId)
                              .update({'isViewed': true});
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ParcelDetailScreen(parcel: data),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // Icon
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getNotificationIcon(status),
                                color: _getStatusColor(status),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getNotificationTitle(status),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isViewed
                                          ? AppColors.textPrimary
                                          : AppColors.primary,
                                    ),
                                  ),
                                  if (riderName != null)
                                    Text(
                                      'Rider: $riderName',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    details.length > 60
                                        ? '${details.substring(0, 60)}...'
                                        : details,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(
                                            status,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _getStatusColor(status),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (!isViewed)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Text(
                                            'NEW',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      if (isViewed)
                                        Text(
                                          createdAt != null
                                              ? _formatTimeAgo(
                                                  createdAt.toDate(),
                                                )
                                              : '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _getNotificationTitle(String status) {
    switch (status) {
      case 'Assigned':
        return 'Parcel Assigned to Rider';
      case 'Picked Up':
        return 'Parcel Picked Up';
      case 'Out for Delivery':
        return 'Out for Delivery';
      default:
        return 'New Parcel';
    }
  }

  IconData _getNotificationIcon(String status) {
    switch (status) {
      case 'Assigned':
        return Icons.local_shipping_rounded;
      case 'Picked Up':
        return Icons.inventory_2_rounded;
      case 'Out for Delivery':
        return Icons.delivery_dining_rounded;
      default:
        return Icons.inventory_rounded;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return AppColors.textSecondary;
      case 'Assigned':
        return AppColors.warning;
      case 'Picked Up':
        return AppColors.info;
      case 'Out for Delivery':
        return AppColors.primaryLight;
      case 'Delivered':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

// Rider Available Parcels Screen
class RiderAvailableParcelsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const RiderAvailableParcelsScreen({super.key, required this.user});

  @override
  State<RiderAvailableParcelsScreen> createState() =>
      _RiderAvailableParcelsScreenState();
}

class _RiderAvailableParcelsScreenState
    extends State<RiderAvailableParcelsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Parcels'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('parcels')
              .where('status', isEqualTo: 'Pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading parcels',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        size: 80,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'No Available Parcels',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'When users submit new parcels, they will appear here for you to accept.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text(
                        'Refresh',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final parcelId = data['parcelId'] ?? doc.id;
                final senderName = data['senderName'] ?? 'Unknown Sender';
                final receiverName = data['receiverName'] ?? 'Unknown Receiver';
                final receiverAddress = data['receiverAddress'] ?? 'No Address';
                final details = data['details'] ?? 'No details provided';
                final createdAt = data['createdAt'] as Timestamp?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(
                                  Icons.local_shipping_rounded,
                                  color: AppColors.primary,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'To: $receiverName',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'From: $senderName',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Details
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailItem(
                                  Icons.location_on_rounded,
                                  receiverAddress,
                                ),
                                const SizedBox(height: 12),
                                if (details.isNotEmpty) ...[
                                  const Text(
                                    'Parcel Details:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    details.length > 100
                                        ? '${details.substring(0, 100)}...'
                                        : details,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Text(
                                  'Parcel ID: ${parcelId.substring(0, 8)}...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Monospace',
                                  ),
                                ),
                                if (createdAt != null)
                                  Text(
                                    'Created: ${_formatDate(createdAt.toDate())}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Accept Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _acceptParcel(parcelId, receiverName),
                              icon: const Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                'Accept Delivery',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Future<void> _acceptParcel(String parcelId, String receiverName) async {
    try {
      await FirebaseFirestore.instance
          .collection('parcels')
          .doc(parcelId)
          .update({
            'riderId': widget.user['phone'],
            'riderName': widget.user['name'],
            'status': 'Assigned',
            'assignedAt': FieldValue.serverTimestamp(),
          });

      Fluttertoast.showToast(
        msg: 'Parcel accepted! Delivery to $receiverName',
        backgroundColor: AppColors.success,
        textColor: Colors.white,
        fontSize: 16,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to accept parcel: $e',
        backgroundColor: AppColors.error,
        textColor: Colors.white,
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}

// Rider Assigned Deliveries Screen
class RiderAssignedDeliveriesScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const RiderAssignedDeliveriesScreen({super.key, required this.user});

  @override
  State<RiderAssignedDeliveriesScreen> createState() =>
      _RiderAssignedDeliveriesScreenState();
}

class _RiderAssignedDeliveriesScreenState
    extends State<RiderAssignedDeliveriesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deliveries'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('parcels')
              .where('riderId', isEqualTo: widget.user['phone'])
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading deliveries',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            final assignedParcels = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? '';
              return status == 'Assigned';
            }).toList();

            final pickedUpParcels = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? '';
              return status == 'Picked Up';
            }).toList();

            final outForDeliveryParcels = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? '';
              return status == 'Out for Delivery';
            }).toList();

            final deliveredParcels = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? '';
              return status == 'Delivered';
            }).toList();

            final allParcels = [
              ...assignedParcels,
              ...pickedUpParcels,
              ...outForDeliveryParcels,
              ...deliveredParcels,
            ];

            if (allParcels.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        size: 80,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'No Assigned Deliveries',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Accept parcels from the Available Parcels section to see them here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RiderAvailableParcelsScreen(user: widget.user),
                          ),
                        );
                      },
                      icon: const Icon(Icons.local_shipping_rounded, size: 20),
                      label: const Text(
                        'View Available Parcels',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Summary Cards
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildSummaryCard(
                        'Assigned',
                        assignedParcels.length,
                        Colors.orange,
                      ),
                      _buildSummaryCard(
                        'Picked Up',
                        pickedUpParcels.length,
                        Colors.blue,
                      ),
                      _buildSummaryCard(
                        'In Transit',
                        outForDeliveryParcels.length,
                        Colors.purple,
                      ),
                      _buildSummaryCard(
                        'Delivered',
                        deliveredParcels.length,
                        Colors.green,
                      ),
                    ],
                  ),
                ),

                // Parcels List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: allParcels.length,
                    itemBuilder: (context, index) {
                      final doc = allParcels[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildParcelCard(data, context);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, int count, Color color) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelCard(Map<String, dynamic> data, BuildContext context) {
    final parcelId = data['parcelId'] ?? '';
    final receiverName = data['receiverName'] ?? 'Unknown Receiver';
    final receiverAddress = data['receiverAddress'] ?? 'No Address';
    final details = data['details'] ?? 'No details provided';
    final currentStatus = data['status'] ?? 'Assigned';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _getStatusColor(currentStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _getStatusIcon(currentStatus),
                      color: _getStatusColor(currentStatus),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receiverName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          receiverAddress,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildActionButton(currentStatus, parcelId, receiverName),
                ],
              ),

              const SizedBox(height: 20),

              // Details
              if (details.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    details.length > 100
                        ? '${details.substring(0, 100)}...'
                        : details,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Parcel ID
              Text(
                'Parcel ID: ${parcelId.substring(0, 8)}...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String currentStatus,
    String parcelId,
    String receiverName,
  ) {
    String buttonText;
    String nextStatus;
    Color buttonColor;

    switch (currentStatus) {
      case 'Assigned':
        buttonText = 'Pick Up';
        nextStatus = 'Picked Up';
        buttonColor = Colors.blue;
        break;
      case 'Picked Up':
        buttonText = 'Start Delivery';
        nextStatus = 'Out for Delivery';
        buttonColor = Colors.purple;
        break;
      case 'Out for Delivery':
        buttonText = 'Deliver';
        nextStatus = 'Delivered';
        buttonColor = Colors.green;
        break;
      default:
        return const SizedBox.shrink();
    }

    return ElevatedButton(
      onPressed: () => _updateParcelStatus(
        parcelId,
        currentStatus,
        nextStatus,
        receiverName,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(buttonText),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Assigned':
        return Colors.orange;
      case 'Picked Up':
        return Colors.blue;
      case 'Out for Delivery':
        return Colors.purple;
      case 'Delivered':
        return Colors.green;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Assigned':
        return Icons.assignment_rounded;
      case 'Picked Up':
        return Icons.inventory_2_rounded;
      case 'Out for Delivery':
        return Icons.local_shipping_rounded;
      case 'Delivered':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  Future<void> _updateParcelStatus(
    String parcelId,
    String currentStatus,
    String nextStatus,
    String receiverName,
  ) async {
    try {
      final updateData = {
        'status': nextStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (nextStatus == 'Picked Up') {
        updateData['pickedUpAt'] = FieldValue.serverTimestamp();
      } else if (nextStatus == 'Out for Delivery') {
        updateData['outForDeliveryAt'] = FieldValue.serverTimestamp();
      } else if (nextStatus == 'Delivered') {
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('parcels')
          .doc(parcelId)
          .update(updateData);

      Fluttertoast.showToast(
        msg: 'Status updated to $nextStatus',
        backgroundColor: AppColors.success,
        textColor: Colors.white,
        fontSize: 16,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to update status: $e',
        backgroundColor: AppColors.error,
        textColor: Colors.white,
      );
    }
  }
}

// Rider Delivery History Screen
class RiderDeliveryHistoryScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const RiderDeliveryHistoryScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('parcels')
              .where('riderId', isEqualTo: user['phone'])
              .where('status', isEqualTo: 'Delivered')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading history',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.history_outlined,
                        size: 80,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'No Delivery History',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Your completed deliveries will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final doc = docs[i];
                final data = doc.data() as Map<String, dynamic>;
                final parcelId = data['parcelId'] ?? doc.id;
                final receiverName = data['receiverName'] ?? 'Receiver';
                final receiverAddress = data['receiverAddress'] ?? '';
                final deliveredAt = data['deliveredAt'] as Timestamp?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  receiverName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  receiverAddress,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Parcel ID: ${parcelId.substring(0, 8)}...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Monospace',
                                  ),
                                ),
                                if (deliveredAt != null)
                                  Text(
                                    'Delivered: ${_formatDate(deliveredAt.toDate())}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Delivered',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (dateDay == DateTime(today.year, today.month, today.day - 1)) {
      return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}

// Rider Scan Parcel Screen
class RiderScanParcelScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const RiderScanParcelScreen({super.key, required this.user});

  @override
  State<RiderScanParcelScreen> createState() => _RiderScanParcelScreenState();
}

class _RiderScanParcelScreenState extends State<RiderScanParcelScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = false;
  String _scannedData = '';
  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Parcel'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? Colors.yellow : Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: Icon(
              _cameraFacing == CameraFacing.back
                  ? Icons.camera_rear_rounded
                  : Icons.camera_front_rounded,
            ),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            // Scanner View
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    controller: cameraController,
                    onDetect: _onBarcodeScanned,
                  ),
                  _buildScannerOverlay(),
                ],
              ),
            ),

            // Instructions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Scan Parcel QR Code',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Point your camera at the QR code generated by the sender',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildStatusInstructions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.5),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.5),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: CustomPaint(painter: _ScannerCornerPainter()),
        ),
      ),
    );
  }

  Widget _buildStatusInstructions() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildInstructionItem(Colors.orange, 'Assigned', 'Scan to Pickup'),
        _buildInstructionItem(
          Colors.blue,
          'Picked Up',
          'Scan to Start Delivery',
        ),
        _buildInstructionItem(
          Colors.purple,
          'Out for Delivery',
          'Scan to Deliver',
        ),
      ],
    );
  }

  Widget _buildInstructionItem(Color color, String status, String action) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$status: $action',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _onBarcodeScanned(BarcodeCapture barcodes) {
    if (_isScanning) return;

    final barcode = barcodes.barcodes.first;
    if (barcode.rawValue == null) return;

    setState(() {
      _isScanning = true;
      _scannedData = barcode.rawValue!;
    });

    _processScannedData(_scannedData);
  }

  Future<void> _processScannedData(String data) async {
    try {
      final decodedData = jsonDecode(data);
      final parcelId = decodedData['parcelId'];
      final type = decodedData['type'];

      if (type != 'parcel') {
        _showErrorDialog('Invalid QR code. Please scan a parcel QR code.');
        return;
      }

      final parcelDoc = await FirebaseFirestore.instance
          .collection('parcels')
          .doc(parcelId)
          .get();

      if (!parcelDoc.exists) {
        _showErrorDialog('Parcel not found. Please check the QR code.');
        return;
      }

      final parcelData = parcelDoc.data()!;
      final currentStatus = parcelData['status'];
      final riderId = parcelData['riderId'];

      if (riderId != widget.user['phone']) {
        _showErrorDialog('This parcel is not assigned to you.');
        return;
      }

      _showActionDialog(parcelData, currentStatus);
    } catch (e) {
      _showErrorDialog('Error processing QR code: $e');
    }
  }

  void _showActionDialog(
    Map<String, dynamic> parcelData,
    String currentStatus,
  ) {
    final parcelId = parcelData['parcelId'];
    final receiverName = parcelData['receiverName'];
    final senderName = parcelData['senderName'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Parcel Found',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogInfo('Sender', senderName),
                    _buildDialogInfo('Receiver', receiverName),
                    _buildDialogInfo('Status', currentStatus),
                    _buildDialogInfo(
                      'Parcel ID',
                      '${parcelId.substring(0, 8)}...',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'What would you like to do?',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _resetScanner();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (currentStatus == 'Assigned')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _confirmPickup(parcelId, receiverName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Pick Up'),
                      ),
                    ),
                  if (currentStatus == 'Picked Up')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _startDelivery(parcelId, receiverName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Start Delivery'),
                      ),
                    ),
                  if (currentStatus == 'Out for Delivery')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _confirmDelivery(parcelId, receiverName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Deliver'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _resetScanner();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _resetScanner();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Scan Another'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmPickup(String parcelId, String receiverName) async {
    try {
      await FirebaseFirestore.instance
          .collection('parcels')
          .doc(parcelId)
          .update({
            'status': 'Picked Up',
            'pickedUpAt': FieldValue.serverTimestamp(),
            'statusUpdatedAt': FieldValue.serverTimestamp(),
          });

      Navigator.pop(context);
      _showSuccessDialog(
        'Parcel Picked Up!',
        'You have successfully picked up the parcel for $receiverName',
      );
    } catch (e) {
      _showErrorDialog('Failed to confirm pickup: $e');
    }
  }

  Future<void> _startDelivery(String parcelId, String receiverName) async {
    try {
      await FirebaseFirestore.instance
          .collection('parcels')
          .doc(parcelId)
          .update({
            'status': 'Out for Delivery',
            'outForDeliveryAt': FieldValue.serverTimestamp(),
            'statusUpdatedAt': FieldValue.serverTimestamp(),
          });

      Navigator.pop(context);
      _showSuccessDialog(
        'Delivery Started!',
        'Parcel is now out for delivery to $receiverName',
      );
    } catch (e) {
      _showErrorDialog('Failed to start delivery: $e');
    }
  }

  Future<void> _confirmDelivery(String parcelId, String receiverName) async {
    try {
      await FirebaseFirestore.instance
          .collection('parcels')
          .doc(parcelId)
          .update({
            'status': 'Delivered',
            'deliveredAt': FieldValue.serverTimestamp(),
            'statusUpdatedAt': FieldValue.serverTimestamp(),
          });

      Navigator.pop(context);
      _showSuccessDialog(
        'Delivery Completed! 🎉',
        'Parcel successfully delivered to $receiverName',
      );
    } catch (e) {
      _showErrorDialog('Failed to confirm delivery: $e');
    }
  }

  void _resetScanner() {
    setState(() {
      _isScanning = false;
      _scannedData = '';
    });
  }

  void _toggleTorch() {
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
    cameraController.toggleTorch();
  }

  void _switchCamera() {
    setState(() {
      _cameraFacing = _cameraFacing == CameraFacing.back
          ? CameraFacing.front
          : CameraFacing.back;
    });
    cameraController.switchCamera();
  }
}

class _ScannerCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const cornerLength = 25.0;
    const cornerWidth = 3.0;

    // Top-left corner
    canvas.drawLine(
      Offset.zero,
      Offset(cornerLength, 0),
      paint..strokeWidth = cornerWidth,
    );
    canvas.drawLine(
      Offset.zero,
      Offset(0, cornerLength),
      paint..strokeWidth = cornerWidth,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      paint..strokeWidth = cornerWidth,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint..strokeWidth = cornerWidth,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      paint..strokeWidth = cornerWidth,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint..strokeWidth = cornerWidth,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      paint..strokeWidth = cornerWidth,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      paint..strokeWidth = cornerWidth,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Signup Screen
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  String selectedRole = 'User';
  bool creating = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Create Your Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Join Drop Lock for secure parcel delivery',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Form
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildTextField(
                        'Full Name',
                        nameCtrl,
                        Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Phone Number',
                        phoneCtrl,
                        Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Email Address',
                        emailCtrl,
                        Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Address',
                        addressCtrl,
                        Icons.location_on_rounded,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      _buildRoleDropdown(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: creating ? null : _createAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 4,
                          ),
                          child: creating
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Login Link
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: RichText(
                  text: TextSpan(
                    text: 'Already have an account? ',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    children: [
                      TextSpan(
                        text: 'Sign In',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.background,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.primary),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: maxLines > 1 ? 16 : 0,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.background,
      ),
      child: TextField(
        controller: passwordCtrl,
        obscureText: _obscurePassword,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: 'Password',
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.primary,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.background,
      ),
      child: DropdownButtonFormField<String>(
        value: selectedRole,
        decoration: InputDecoration(
          labelText: 'Role',
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: const Icon(
            Icons.person_outline_rounded,
            color: AppColors.primary,
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
        ),
        items: const [
          DropdownMenuItem(value: 'User', child: Text('User')),
          DropdownMenuItem(value: 'Rider', child: Text('Rider')),
        ],
        onChanged: (value) => setState(() => selectedRole = value ?? 'User'),
      ),
    );
  }

  Future<void> _createAccount() async {
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pwd = passwordCtrl.text.trim();
    final address = addressCtrl.text.trim();
    final role = selectedRole;

    if ([name, phone, email, pwd, address].any((s) => s.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All fields are required'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => creating = true);
    try {
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Phone number already registered'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Generate user ID in format user_XXXXXX (6 random digits)
      final random = Random();
      final randomDigits = List.generate(6, (_) => random.nextInt(10)).join();
      final userId = 'user_$randomDigits';

      final hashed = sha256.convert(utf8.encode(pwd)).toString();
      final docRef = await FirebaseFirestore.instance.collection('users').add({
        'userId': userId,
        'name': name,
        'phone': phone,
        'email': email,
        'password': hashed,
        'role': role,
        'senderAddress': address,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _saveLogin(
        userId: docRef.id,
        phone: phone,
        role: role,
        plainPassword: pwd,
      );

      final user = {
        'name': name,
        'phone': phone,
        'email': email,
        'role': role,
        'senderAddress': address,
      };
      Widget page = role == 'Rider'
          ? RiderDashboard(user: user)
          : UserDashboard(user: user);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      setState(() => creating = false);
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    addressCtrl.dispose();
    super.dispose();
  }
}

// Forgot Password Screen
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  bool resetting = false;
  String? error;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.lock_reset_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Enter your email and new password',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Form
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildTextField(
                        'Email Address',
                        emailCtrl,
                        Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        'New Password',
                        newPasswordCtrl,
                        _obscureNewPassword,
                        () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        'Confirm New Password',
                        confirmPasswordCtrl,
                        _obscureConfirmPassword,
                        () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: resetting ? null : _resetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 4,
                          ),
                          child: resetting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Reset Password',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Back to Login
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Back to Login',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.background,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.primary),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool obscureText,
    VoidCallback onToggle,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.background,
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.primary,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: onToggle,
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _resetPassword() async {
    final email = emailCtrl.text.trim();
    final newPassword = newPasswordCtrl.text.trim();
    final confirmPassword = confirmPasswordCtrl.text.trim();

    if (email.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() => error = 'All fields are required');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => error = 'Passwords do not match');
      return;
    }

    if (newPassword.length < 6) {
      setState(() => error = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      resetting = true;
      error = null;
    });

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        setState(() => error = 'No account found with this email');
        return;
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      final hashedNewPassword = sha256
          .convert(utf8.encode(newPassword))
          .toString();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .update({
            'password': hashedNewPassword,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      try {
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser != null && authUser.email == email) {
          await authUser.updatePassword(newPassword);
        }
      } catch (e) {
        print('Auth password update failed: $e');
      }

      final saved = await _loadSaved();
      if (saved['email'] == email) {
        await _secureStorage.write(key: 'saved_password', value: newPassword);
      }

      Fluttertoast.showToast(
        msg: 'Password reset successfully!',
        backgroundColor: AppColors.success,
        textColor: Colors.white,
        fontSize: 16,
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => error = 'Error resetting password: $e');
    } finally {
      setState(() => resetting = false);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }
}
