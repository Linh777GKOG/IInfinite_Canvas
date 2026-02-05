import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'pages/gallery_page.dart';
import 'pages/auth_page.dart';

void main() async {
  // 1. Đảm bảo Flutter Binding được khởi tạo trước
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Khởi tạo Firebase (ĐÚNG cho mọi platform)
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: kIsWeb ? DefaultFirebaseOptions.currentPlatform : null,
    );
    firebaseReady = true;
  } catch (e) {
    debugPrint('Lỗi khởi tạo Firebase: $e');
    firebaseReady = false;
  }

  // 3. Cho phép xoay mọi hướng
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(MyApp(firebaseReady: firebaseReady));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Infinite canvas',

      // Giữ nguyên Theme Dark
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF32C5FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF32C5FF),
          secondary: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIconColor: Colors.white70,
        ),
      ),

      // LOGIC KIỂM TRA ĐĂNG NHẬP
      home: firebaseReady
          ? StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF32C5FF),
                      ),
                    ),
                  );
                }

                if (snapshot.hasData) {
                  return const GalleryPage();
                }

                return const AuthPage();
              },
            )
          : const _FirebaseSetupPage(),
    );
  }
}

class _FirebaseSetupPage extends StatelessWidget {
  const _FirebaseSetupPage();

  @override
  Widget build(BuildContext context) {
    final platformHint = kIsWeb
        ? 'Bạn đang chạy trên Web nên bắt buộc cần FlutterFire options.'
        : 'Nếu bạn chạy trên iOS, cần thêm GoogleService-Info.plist.';

    return Scaffold(
      appBar: AppBar(title: const Text('Firebase chưa cấu hình')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ứng dụng đã chạy nhưng Firebase chưa khởi tạo được.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(platformHint),
            const SizedBox(height: 12),
            const Text('Cách khắc phục nhanh:'),
            const SizedBox(height: 8),
            const Text(
              '1) Cài FlutterFire CLI: dart pub global activate flutterfire_cli',
            ),
            const Text('2) Đăng nhập Firebase: firebase login'),
            const Text('3) Chạy: flutterfire configure'),
            const SizedBox(height: 12),
            const Text(
              'Hoặc chạy trên Android (đã có google-services.json) để test nhanh.',
            ),
          ],
        ),
      ),
    );
  }
}
