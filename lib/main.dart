import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart'; //  Import Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; //  Import Firebase Auth

import 'pages/gallery_page.dart';
import 'pages/auth_page.dart'; //  Import trang Auth mới tạo

void main() async {
  // 1. Đảm bảo Flutter Binding được khởi tạo trước
  WidgetsFlutterBinding.ensureInitialized();

  // 2.  Khởi tạo Firebase (QUAN TRỌNG)
  // Nếu chưa có file google-services.json, bước này sẽ gây Crash
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Lỗi khởi tạo Firebase: $e");
  }

  // 3. Cho phép xoay mọi hướng
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        // Cấu hình Input cho trang Login đẹp hơn trong nền tối
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIconColor: Colors.white70,
        ),
      ),

      //  LOGIC KIỂM TRA ĐĂNG NHẬP
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // A. Đang kết nối/kiểm tra... -> Hiện vòng xoay
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Color(0xFF32C5FF))),
            );
          }

          // B. Có dữ liệu User -> Đã đăng nhập -> Vào Gallery
          if (snapshot.hasData) {
            return const GalleryPage();
          }

          // C. Không có user -> Chưa đăng nhập -> Vào trang Login/Register
          return const AuthPage();
        },
      ),
    );
  }
}