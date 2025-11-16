import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DropLockApp());
}

/* =========================
   Storage helpers
========================= */
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

class DropLockApp extends StatelessWidget {
  const DropLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drop Lock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9C6BD6)),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/forgot': (_) => const ForgotPasswordScreen(),
      },
    );
  }
}

/* =========================
   Rich Splash Screen
========================= */
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _attemptAutoLogin();
  }

  Future<void> _attemptAutoLogin() async {
    final saved = await _loadSaved();
    final userId = saved['userId'];
    await Future.delayed(const Duration(milliseconds: 3000));

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
      } catch (_) {
        // ignore - fallthrough to login
      }
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
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFFF093FB)],
          ),
        ),
        child: Stack(
          children: [
            // Background circles
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              right: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo container
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7E57C2), Color(0xFF5E35B1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 70,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // App name
                  const Text(
                    'DROP LOCK',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.black26,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tagline
                  const Text(
                    'Secure Parcel Delivery',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 80),

                  // Loading indicator
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Loading text
                  const Text(
                    'Securing your deliveries...',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ],
              ),
            ),

            // Bottom info
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const Text(
                    'Secure • Fast • Reliable',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
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

/* =========================
   Login Screen 
========================= */
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

  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _anim.forward();
    _prefill();
  }

  @override
  void dispose() {
    _anim.dispose();
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
        error = 'Phone, password and role are required';
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
        MaterialPageRoute(builder: (_) => page),
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
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5E9FF), Color(0xFFE3D3F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width > 700 ? 640 : width - 24,
              ),
              child: ScaleTransition(
                scale: _scale,
                child: Card(
                  color: Colors.white,
                  elevation: 12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF7E57C2,
                                ).withOpacity(0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.lock,
                                color: Color(0xFF7E57C2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Drop Lock',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A148C),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Login to your Drop Lock account',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.phone),
                            hintText: 'Phone number',
                            filled: true,
                            fillColor: const Color(0xFFF7F0FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock),
                            hintText: 'Password',
                            filled: true,
                            fillColor: const Color(0xFFF7F0FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: const Color(0xFFF7F0FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          hint: const Text('Select Role'),
                          items: const [
                            DropdownMenuItem(
                              value: 'User',
                              child: Text('User'),
                            ),
                            DropdownMenuItem(
                              value: 'Rider',
                              child: Text('Rider'),
                            ),
                          ],
                          onChanged: (v) => setState(() => selectedRole = v),
                        ),
                        const SizedBox(height: 16),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ElevatedButton(
                          onPressed: loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E57C2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/signup'),
                              child: const Text('Create account'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/forgot'),
                              child: const Text('Forgot password?'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* =========================
   Logout helper
========================= */
void logout(BuildContext context) async {
  await _clearSaved();
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

/* =========================
   User Dashboard 
========================= */
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

  Widget _menuButton(
    BuildContext context,
    String text,
    IconData icon,
    Widget page, {
    int? notificationCount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ElevatedButton.icon(
        onPressed: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        icon: Stack(
          children: [
            Icon(icon, color: const Color(0xFF7E57C2)),
            if (notificationCount != null && notificationCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    notificationCount > 9 ? '9+' : notificationCount.toString(),
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
        label: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF7E57C2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (notificationCount != null && notificationCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    notificationCount > 9 ? '9+' : notificationCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        style: ElevatedButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor: const Color(0xFFF3E8FF),
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

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

              // Count unread notifications (only non-delivered parcels)
              if (!isViewed && status != 'Delivered') {
                unreadCount++;
              }

              // Show popup for new parcels that aren't delivered
              final isNewParcel = doc.type == DocumentChangeType.added;
              if (isNewParcel &&
                  !_seenParcelIds.contains(parcelId) &&
                  status != 'Delivered') {
                _seenParcelIds.add(parcelId);
                newParcels.add(data);
              }
            }

            // Show popups for new parcels
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

  // Method to clear notification badges (called from Notifications screen)
  void _clearNotificationBadges() {
    if (mounted) {
      setState(() {
        _unreadNotifications = 0;
      });
    }
  }

  Future<void> _showNewParcelPopup(Map<String, dynamic> parcelData) async {
    if (!mounted) return;

    final senderName = parcelData['senderName'] ?? 'Sender';
    final details = parcelData['details'] ?? '';
    final parcelId = parcelData['parcelId'] ?? '';
    final status = parcelData['status'] ?? 'Pending';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('📦 New Parcel Assigned'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: $senderName'),
            const SizedBox(height: 6),
            Text('Status: $status'),
            const SizedBox(height: 6),
            Text('Parcel ID: ${parcelId.substring(0, 8)}...'),
            const SizedBox(height: 6),
            Text(
              details.toString().isNotEmpty
                  ? details.toString()
                  : 'Tap to view parcel details',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ParcelDetailScreen(parcel: parcelData),
                ),
              );
            },
            child: const Text('View Details'),
          ),
        ],
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
    final userName = widget.user['name'] ?? 'Profile Name';
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Dashboard'),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_unreadNotifications > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserNotificationsScreen(
                            user: widget.user,
                            onNotificationsViewed: _clearNotificationBadges,
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        _unreadNotifications > 9
                            ? '9+'
                            : _unreadNotifications.toString(),
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
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFEDE1F9),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7E57C2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7E57C2),
                          ),
                        ),
                        if (_unreadNotifications > 0)
                          Text(
                            '$_unreadNotifications new parcel${_unreadNotifications > 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              _menuButton(
                context,
                'Submit a Parcel',
                Icons.add_shopping_cart,
                SubmitOrderScreen(user: widget.user),
              ),
              _menuButton(
                context,
                'Incoming Parcels',
                Icons.inbox,
                IncomingParcelsScreen(user: widget.user),
                notificationCount: _unreadNotifications,
              ),
              _menuButton(
                context,
                'Track Parcel',
                Icons.location_on,
                UserTrackScreen(user: widget.user),
              ),
              _menuButton(
                context,
                'Check Parcel Status',
                Icons.search,
                CheckingOrderStatusScreen(user: widget.user),
              ),
              _menuButton(
                context,
                'Parcel History',
                Icons.history,
                ParcelHistoryScreen(user: widget.user),
              ),
              _menuButton(
                context,
                'Notifications',
                Icons.notifications,
                UserNotificationsScreen(
                  user: widget.user,
                  onNotificationsViewed: _clearNotificationBadges,
                ),
                notificationCount: _unreadNotifications,
              ),

              // Debug button (always show for testing)
              _menuButton(
                context,
                'Debug: Check My Parcels',
                Icons.bug_report,
                DebugParcelsScreen(user: widget.user),
              ),
              const Spacer(),
              Center(
                child: ElevatedButton(
                  onPressed: () => logout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E57C2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 14,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================
   Debug Parcels Screen (for testing notifications)
========================= */
class DebugParcelsScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const DebugParcelsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final phone = user['phone'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug: My Parcels'),
        backgroundColor: const Color(0xFF7E57C2),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parcels')
            .where('receiverPhone', isEqualTo: phone)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: const Color(0xFFF3E8FF),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Debug Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Your phone: $phone'),
                        Text('Total parcels found: ${docs.length}'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            // Create a test parcel for debugging
                            _createTestParcel(phone!);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E57C2),
                          ),
                          child: const Text('Create Test Parcel'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final parcelId = data['parcelId'] ?? docs[i].id;
                    final status = data['status'] ?? 'Unknown';
                    final isViewed = data['isViewed'] ?? false;
                    final senderName = data['senderName'] ?? 'Unknown';
                    final receiverName = data['receiverName'] ?? 'Unknown';
                    final receiverPhone = data['receiverPhone'] ?? 'Unknown';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      color: isViewed ? Colors.white : const Color(0xFFFFF9C4),
                      child: ListTile(
                        leading: Icon(
                          isViewed ? Icons.visibility : Icons.visibility_off,
                          color: isViewed ? Colors.green : Colors.orange,
                        ),
                        title: Text('Parcel: ${parcelId.substring(0, 8)}...'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('From: $senderName'),
                            Text('To: $receiverName ($receiverPhone)'),
                            Text('Status: $status'),
                            Text('Viewed: $isViewed'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_red_eye,
                                color: Colors.blue,
                              ),
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection('parcels')
                                    .doc(docs[i].id)
                                    .update({'isViewed': true});
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.visibility_off,
                                color: Colors.orange,
                              ),
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection('parcels')
                                    .doc(docs[i].id)
                                    .update({'isViewed': false});
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ParcelDetailScreen(parcel: data),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createTestParcel(String userPhone) async {
    try {
      final parcelId = const Uuid().v4();
      await FirebaseFirestore.instance.collection('parcels').doc(parcelId).set({
        'senderId': 'test_sender',
        'senderName': 'Test Sender',
        'senderPhone': '+1234567890',
        'senderAddress': 'Test Sender Address',
        'receiverName': user['name'] ?? 'Test Receiver',
        'receiverPhone': userPhone,
        'receiverAddress': 'Test Receiver Address',
        'details': 'This is a test parcel created for debugging notifications',
        'createdAt': FieldValue.serverTimestamp(),
        'parcelId': parcelId,
        'status': 'Pending',
        'isViewed': false,
      });

      Fluttertoast.showToast(msg: 'Test parcel created! Check notifications.');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to create test parcel: $e');
    }
  }
}

/* =========================
   Submit Order Screen 
========================= */
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

  @override
  void initState() {
    super.initState();
    // Pre-fill sender details
    senderName.text = widget.user['name'] ?? '';
    senderPhone.text = widget.user['phone'] ?? '';
    senderAddress.text = widget.user['senderAddress'] ?? '';
  }

  Future<void> _submitParcel() async {
    final sName = senderName.text.trim();
    final sPhone = senderPhone.text.trim();
    final sAddress = senderAddress.text.trim();
    final rName = receiverName.text.trim();
    final rPhone = receiverPhone.text.trim();
    final rAddress = receiverAddress.text.trim();
    final details = parcelDetails.text.trim();

    if ([
      sName,
      sPhone,
      sAddress,
      rName,
      rPhone,
      rAddress,
      details,
    ].any((s) => s.isEmpty)) {
      Fluttertoast.showToast(msg: 'All fields are required');
      return;
    }

    final parcelId = const Uuid().v4();

    await FirebaseFirestore.instance.collection('parcels').doc(parcelId).set({
      'senderId': widget.user['phone'],
      'senderName': sName,
      'senderPhone': sPhone,
      'senderAddress': sAddress,
      'receiverName': rName,
      'receiverPhone': rPhone,
      'receiverAddress': rAddress,
      'details': details,
      'createdAt': FieldValue.serverTimestamp(),
      'parcelId': parcelId,
      'status': 'Pending',
      'isViewed': false, // Add this field for notifications
    });

    final qrData = jsonEncode({
      'parcelId': parcelId,
      'senderName': sName,
      'senderPhone': sPhone,
      'senderAddress': sAddress,
      'receiverName': rName,
      'receiverPhone': rPhone,
      'receiverAddress': rAddress,
      'details': details,
    });

    await _showQRDialog(qrData);

    // Clear only receiver fields
    receiverName.clear();
    receiverPhone.clear();
    receiverAddress.clear();
    parcelDetails.clear();
  }

  Future<void> _showQRDialog(String data) async {
    final qrBytes = await _generateQRBytes(data);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Parcel QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 200, height: 200, child: Image.memory(qrBytes)),
            const SizedBox(height: 10),
            const Text(
              'Parcel submitted successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
        title: const Text('Submit Order'),
        backgroundColor: const Color(0xFF7E57C2),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sender Information Section
              const Text(
                'Sender Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E57C2),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: senderName,
                decoration: const InputDecoration(
                  labelText: 'Sender Name *',
                  hintText: 'Enter sender name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: senderPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Sender Phone *',
                  hintText: 'Enter sender phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: senderAddress,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Sender Address *',
                  hintText: 'Enter sender address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),

              // Receiver Information Section
              const Text(
                'Receiver Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E57C2),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: receiverName,
                decoration: const InputDecoration(
                  labelText: 'Receiver Name *',
                  hintText: 'Enter receiver name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: receiverPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Receiver Phone *',
                  hintText: 'Enter receiver phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: receiverAddress,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Receiver Address *',
                  hintText: 'Enter receiver address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),

              // Parcel Details Section
              const Text(
                'Parcel Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E57C2),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: parcelDetails,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Parcel Description *',
                  hintText: 'Describe the parcel contents, size, weight, etc.',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _submitParcel,
                icon: const Icon(Icons.qr_code),
                label: const Text('Submit & Generate QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E57C2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================
   Incoming Parcels 
========================= */
class IncomingParcelsScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const IncomingParcelsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final phone = user['phone'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Parcels'),
        backgroundColor: const Color(0xFF7E57C2),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parcels')
            .where('receiverPhone', isEqualTo: phone)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? [];
          // filter out delivered if you want only active parcels
          final active = docs.where((d) {
            final m = d.data() as Map<String, dynamic>;
            final status = m['status'] ?? '';
            return status != 'Delivered';
          }).toList();
          if (active.isEmpty)
            return const Center(child: Text('No incoming parcels.'));
          return ListView.builder(
            itemCount: active.length,
            itemBuilder: (context, i) {
              final data = active[i].data() as Map<String, dynamic>;
              final parcelId = data['parcelId'] ?? active[i].id;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: ListTile(
                  title: Text(data['senderName'] ?? 'Sender'),
                  subtitle: Text(
                    'Parcel ID: $parcelId\nStatus: ${data['status'] ?? 'Pending'}',
                  ),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ParcelDetailScreen(parcel: data),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E57C2),
                    ),
                    child: const Text('View'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/* =========================
   Parcel Detail Screen 
========================= */
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

    // Mark parcel as viewed when opened
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
        backgroundColor: const Color(0xFF7E57C2),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parcel ID: $parcelId',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text('Status: $status'),
            const Divider(height: 30),
            const Text(
              'Sender',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('Name: $senderName'),
            Text('Phone: $senderPhone'),
            Text('Address: $senderAddress'),
            const Divider(height: 30),
            const Text(
              'Receiver',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('Name: $receiverName'),
            Text('Phone: $receiverPhone'),
            Text('Address: $receiverAddress'),
            const Divider(height: 30),
            const Text(
              'Parcel Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(details.toString()),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Fluttertoast.showToast(msg: 'Parcel acknowledged');
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Acknowledge Receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E57C2),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================
   User Track & Check Status placeholders
========================= */
class UserTrackScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const UserTrackScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Parcel'),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Map / tracking UI goes here. Integrate Google Maps when ready.',
        ),
      ),
    );
  }
}

/* =========================
   Checking Order Status Screen
========================= */
class CheckingOrderStatusScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const CheckingOrderStatusScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checking Order Status'),
        backgroundColor: const Color(0xFF7E57C2),
      ),
      body: const Center(child: Text('Order status UI here')),
    );
  }
}

/* =========================
   Parcel History (user) 
========================= */
class ParcelHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ParcelHistoryScreen({super.key, required this.user});

  @override
  State<ParcelHistoryScreen> createState() => _ParcelHistoryScreenState();
}

class _ParcelHistoryScreenState extends State<ParcelHistoryScreen> {
  String _filter =
      'All'; // 'All', 'Pending', 'Assigned', 'Picked Up', 'Delivered'

  @override
  Widget build(BuildContext context) {
    final phone = widget.user['phone'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcel History'),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.grey[50],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  _buildFilterChip('Pending'),
                  _buildFilterChip('Assigned'),
                  _buildFilterChip('Picked Up'),
                  _buildFilterChip('Delivered'),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('parcels')
                  .where('senderPhone', isEqualTo: phone)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                // Local sorting by creation date (newest first)
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aDate = aData['createdAt'] as Timestamp?;
                  final bDate = bData['createdAt'] as Timestamp?;

                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return bDate.compareTo(aDate); // Descending order
                });

                // Filter parcels based on selected filter
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'Pending';
                  return _filter == 'All' || status == _filter;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, i) {
                    final data = filteredDocs[i].data() as Map<String, dynamic>;
                    return _buildParcelItem(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(status),
        selected: _filter == status,
        onSelected: (selected) {
          setState(() {
            _filter = selected ? status : 'All';
          });
        },
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF7E57C2),
        labelStyle: TextStyle(
          color: _filter == status ? Colors.white : Colors.black87,
        ),
        checkmarkColor: Colors.white,
      ),
    );
  }

  Widget _buildParcelItem(Map<String, dynamic> data) {
    final status = data['status'] ?? 'Pending';
    final receiverName = data['receiverName'] ?? 'Receiver';
    final receiverAddress = data['receiverAddress'] ?? '';
    final parcelId = data['parcelId'] ?? '';
    final details = data['details'] ?? 'No details provided';
    final createdAt = data['createdAt'] as Timestamp?;
    final riderName = data['riderName'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: _buildStatusIcon(status),
        title: Text(
          receiverName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To: $receiverAddress',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              details.length > 50 ? '${details.substring(0, 50)}...' : details,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (riderName != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Rider: $riderName',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ],
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Created: ${_formatDate(createdAt.toDate())}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ParcelDetailScreen(parcel: data)),
          );
        },
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'Delivered':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 20),
        );
      case 'Picked Up':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.inventory_2, color: Colors.white, size: 20),
        );
      case 'Assigned':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.local_shipping,
            color: Colors.white,
            size: 20,
          ),
        );
      default: // Pending
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.pending, color: Colors.white, size: 20),
        );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Delivered':
        return Colors.green;
      case 'Picked Up':
        return Colors.blue;
      case 'Assigned':
        return Colors.orange;
      case 'Pending':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _filter == 'All' ? 'No parcels sent yet' : 'No $_filter parcels',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filter == 'All'
                ? 'Send your first parcel to see it here!'
                : 'No parcels with $_filter status',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_filter != 'All')
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _filter = 'All';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E57C2),
              ),
              child: const Text('View All Parcels'),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/* =========================
   User Notifications Screen
========================= */
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
    // Clear notification badges when user opens the notifications screen
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
        backgroundColor: const Color(0xFF7E57C2),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parcels')
            .where('receiverPhone', isEqualTo: phone)
            // REMOVED orderBy to fix the index error
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          // Sort locally by creation date (newest first)
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['createdAt'] as Timestamp?;
            final bDate = bData['createdAt'] as Timestamp?;

            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate); // Descending order
          });

          // Filter parcels to show only relevant ones for notifications
          final notificationParcels = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? '';
            // Show parcels that are not delivered
            return status != 'Delivered';
          }).toList();

          if (notificationParcels.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'New parcel assignments will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notificationParcels.length,
            itemBuilder: (context, i) {
              final doc = notificationParcels[i];
              final data = doc.data() as Map<String, dynamic>;
              final parcelId = data['parcelId'] ?? doc.id;
              final status = data['status'] ?? 'Pending';
              final isViewed = data['isViewed'] ?? false;
              final senderName = data['senderName'] ?? 'Sender';
              final receiverName = data['receiverName'] ?? 'Receiver';
              final details = data['details'] ?? 'No details';
              final createdAt = data['createdAt'] as Timestamp?;
              final riderName = data['riderName'];

              // Determine notification type and icon
              IconData icon;
              Color iconColor;
              String title;

              switch (status) {
                case 'Assigned':
                  icon = Icons.local_shipping;
                  iconColor = Colors.orange;
                  title = 'Parcel Assigned to Rider';
                  break;
                case 'Picked Up':
                  icon = Icons.inventory_2;
                  iconColor = Colors.blue;
                  title = 'Parcel Picked Up';
                  break;
                case 'Out for Delivery':
                  icon = Icons.delivery_dining;
                  iconColor = Colors.purple;
                  title = 'Out for Delivery';
                  break;
                default:
                  icon = Icons.inventory;
                  iconColor = Colors.grey;
                  title = 'New Parcel';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: isViewed ? Colors.white : const Color(0xFFF3E8FF),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isViewed
                              ? Colors.grey[700]
                              : const Color(0xFF7E57C2),
                        ),
                      ),
                      if (riderName != null && status != 'Pending')
                        Text(
                          'Rider: $riderName',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From: $senderName'),
                      const SizedBox(height: 2),
                      Text(
                        details.length > 50
                            ? '${details.substring(0, 50)}...'
                            : details,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!isViewed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (createdAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _formatDate(createdAt.toDate()),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Mark as viewed when tapped
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.grey;
      case 'Assigned':
        return Colors.orange;
      case 'Picked Up':
        return Colors.blue;
      case 'Out for Delivery':
        return Colors.purple;
      case 'Delivered':
        return Colors.green;
      default:
        return Colors.grey;
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

/* =========================
   Rider Dashboard 
========================= */
class RiderDashboard extends StatelessWidget {
  final Map<String, dynamic> user;
  const RiderDashboard({super.key, required this.user});

  Widget _menuButton(
    BuildContext context,
    String text,
    IconData icon,
    Widget page,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ElevatedButton.icon(
        onPressed: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        icon: Icon(icon, color: const Color(0xFF7E57C2)),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF7E57C2),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor: const Color(0xFFF3E8FF),
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riderName = user['name'] ?? 'Rider';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Dashboard'),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFEDE1F9),
                    child: Text(
                      riderName.isNotEmpty ? riderName[0].toUpperCase() : 'R',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7E57C2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    riderName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7E57C2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              _menuButton(
                context,
                'Available Parcels',
                Icons.local_shipping,
                RiderAvailableParcelsScreen(user: user),
              ),
              _menuButton(
                context,
                'Assigned Deliveries',
                Icons.assignment,
                RiderAssignedDeliveriesScreen(user: user),
              ),
              _menuButton(
                context,
                'Delivery History',
                Icons.history,
                RiderDeliveryHistoryScreen(user: user),
              ),
              _menuButton(
                context,
                'Scan QR to Pickup/Deliver',
                Icons.qr_code_scanner,
                RiderScanParcelScreen(user: user),
              ),

              const Spacer(),
              Center(
                child: ElevatedButton(
                  onPressed: () => logout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E57C2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 14,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================
   Rider Screens: Available Parcels & Assigned Deliveries
========================= */

class RiderAvailableParcelsScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const RiderAvailableParcelsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Note: Firestore queries combining isNull and whereIn may be restricted on some runtimes.
    // If you get errors, split into two queries or adjust indexes.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Parcels'),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parcels')
            .where('riderId', isNull: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? [];
          // filter client-side for statuses if needed
          final available = docs.where((d) {
            final m = d.data() as Map<String, dynamic>;
            final status = (m['status'] ?? '').toString();
            return status == 'Pending' || status == 'Assigned';
          }).toList();
          if (available.isEmpty)
            return const Center(child: Text('No parcels available.'));
          return ListView.builder(
            itemCount: available.length,
            itemBuilder: (context, i) {
              final data = available[i].data() as Map<String, dynamic>;
              final parcelId = data['parcelId'] ?? available[i].id;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: ListTile(
                  title: Text(data['receiverName'] ?? 'No name'),
                  subtitle: Text(
                    'To: ${data['receiverAddress'] ?? ''}\nParcel: $parcelId',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('parcels')
                            .doc(parcelId)
                            .update({
                              'riderId': user['phone'],
                              'riderName': user['name'],
                              'status': 'Assigned',
                              'assignedAt': FieldValue.serverTimestamp(),
                            });
                        Fluttertoast.showToast(msg: 'Parcel assigned to you');
                      } catch (e) {
                        Fluttertoast.showToast(msg: 'Failed to accept: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E57C2),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class RiderAssignedDeliveriesScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const RiderAssignedDeliveriesScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // rider sees assigned and picked up parcels, can update status
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Deliveries'),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parcels')
            .where('riderId', isEqualTo: user['phone'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? [];
          final filtered = docs.where((d) {
            final m = d.data() as Map<String, dynamic>;
            final status = (m['status'] ?? '').toString();
            return status == 'Assigned' || status == 'Picked Up';
          }).toList();
          if (filtered.isEmpty)
            return const Center(child: Text('No assigned deliveries.'));
          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final data = filtered[i].data() as Map<String, dynamic>;
              final parcelId = data['parcelId'] ?? filtered[i].id;
              final currentStatus = data['status'] ?? 'Assigned';
              final nextLabel = currentStatus == 'Assigned'
                  ? 'Pick Up'
                  : 'Deliver';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: ListTile(
                  title: Text(data['receiverName'] ?? 'Receiver'),
                  subtitle: Text(
                    'Address: ${data['receiverAddress'] ?? ''}\nStatus: $currentStatus\nParcel: $parcelId',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      try {
                        final newStatus = currentStatus == 'Assigned'
                            ? 'Picked Up'
                            : 'Delivered';
                        await FirebaseFirestore.instance
                            .collection('parcels')
                            .doc(parcelId)
                            .update({
                              'status': newStatus,
                              'statusUpdatedAt': FieldValue.serverTimestamp(),
                            });
                        Fluttertoast.showToast(
                          msg: 'Status updated to $newStatus',
                        );
                      } catch (e) {
                        Fluttertoast.showToast(
                          msg: 'Failed to update status: $e',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E57C2),
                    ),
                    child: Text(nextLabel),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class RiderDeliveryHistoryScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const RiderDeliveryHistoryScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery History'),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parcels')
            .where('riderId', isEqualTo: user['phone'])
            .where('status', isEqualTo: 'Delivered')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty)
            return const Center(child: Text('No deliveries completed yet.'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['receiverName'] ?? 'Receiver'),
                subtitle: Text(
                  'Delivered to: ${data['receiverAddress'] ?? ''}\nParcel: ${data['parcelId'] ?? docs[i].id}',
                ),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              );
            },
          );
        },
      ),
    );
  }
}

class RiderScanParcelScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const RiderScanParcelScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Integrate qr_code_scanner/mobile_scanner on device builds
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'QR Scanner UI here (to confirm pickup/delivery). Integrate plugin for scanning.',
        ),
      ),
    );
  }
}

/* =========================
   Signup Screen 
========================= */
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

  Future<void> _createAccount() async {
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pwd = passwordCtrl.text.trim();
    final address = addressCtrl.text.trim();
    final role = selectedRole;

    if ([name, phone, email, pwd, address].any((s) => s.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All fields required')));
      return;
    }

    setState(() => creating = true);
    try {
      // Check if phone already exists
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone already registered')),
        );
        return;
      }

      final hashed = sha256.convert(utf8.encode(pwd)).toString();
      final docRef = await FirebaseFirestore.instance.collection('users').add({
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  Widget _input(
    String hint,
    TextEditingController c,
    IconData icon, {
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF7F0FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5E9FF), Color(0xFFEEDBF9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Card(
            color: Colors.white,
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _input('Full name', nameCtrl, Icons.person),
                  const SizedBox(height: 10),
                  _input(
                    'Phone',
                    phoneCtrl,
                    Icons.phone,
                    keyboard: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  _input(
                    'Email',
                    emailCtrl,
                    Icons.email,
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  _input('Password', passwordCtrl, Icons.lock, obscure: true),
                  const SizedBox(height: 10),
                  _input('Address', addressCtrl, Icons.location_on),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person),
                      filled: true,
                      fillColor: const Color(0xFFF7F0FF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'User', child: Text('User')),
                      DropdownMenuItem(value: 'Rider', child: Text('Rider')),
                    ],
                    onChanged: (v) =>
                        setState(() => selectedRole = v ?? 'User'),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: creating ? null : _createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E57C2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: creating
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Sign Up',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* =========================
   Forgot Password Screen 
========================= */
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

  Future<void> _resetPassword() async {
    final email = emailCtrl.text.trim();
    final newPassword = newPasswordCtrl.text.trim();
    final confirmPassword = confirmPasswordCtrl.text.trim();

    // Validation
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
      // First, find the user by email in Firestore
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

      // Update password in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .update({
            'password': hashedNewPassword,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Also try to update in Firebase Auth if the user exists there
      try {
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser != null && authUser.email == email) {
          await authUser.updatePassword(newPassword);
        }
      } catch (e) {
        // Ignore auth errors - we've already updated Firestore
        print('Auth password update failed: $e');
      }

      // Update saved credentials if this is the currently logged-in user
      final saved = await _loadSaved();
      if (saved['email'] == email) {
        await _secureStorage.write(key: 'saved_password', value: newPassword);
      }

      Fluttertoast.showToast(
        msg: 'Password reset successfully!',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      // Navigate back to login
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5E9FF), Color(0xFFE3D3F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.lock_reset,
                          color: Color(0xFF7E57C2),
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A148C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your email and new password',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),

                    // Email Field
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: Color(0xFFF7F0FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // New Password Field
                    TextField(
                      controller: newPasswordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: Color(0xFFF7F0FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password Field
                    TextField(
                      controller: confirmPasswordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: const Color(0xFFF7F0FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _resetPassword(),
                    ),

                    // Error Message
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Reset Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: resetting ? null : _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E57C2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: resetting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Reset Password',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Back to Login
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Back to Login',
                        style: TextStyle(color: Color(0xFF7E57C2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
