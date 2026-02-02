import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Biến này quyết định đang ở màn hình nào
  // true: Đăng Nhập
  // false: Đăng Ký
  bool isLogin = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String? errorMessage;
  bool isLoading = false;

  // Hàm xử lý khi bấm nút Submit
  Future<void> _submit() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (isLogin) {
        // --- LOGIC ĐĂNG NHẬP (Giữ nguyên) ---
        await AuthService().signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // --- LOGIC ĐĂNG KÝ (Đã sửa) ---

        // 1. Kiểm tra mật khẩu khớp nhau
        if (_passwordController.text != _confirmController.text) {
          throw FirebaseAuthException(code: 'password-mismatch', message: "Mật khẩu xác nhận không khớp");
        }

        // 2. Tạo tài khoản
        await AuthService().signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 🔥 3. QUAN TRỌNG: Đăng xuất ngay lập tức!
        // Việc này ngăn không cho StreamBuilder ở main.dart tự chuyển sang GalleryPage
        await FirebaseAuth.instance.signOut();

        // 4. Chuyển giao diện về Đăng nhập & Thông báo thành công
        if (mounted) {
          setState(() {
            isLogin = true; // Chuyển về màn hình Đăng nhập
            errorMessage = null;
            _passwordController.clear(); // Xóa pass cũ
            _confirmController.clear();
          });

          // Hiện thông báo màu xanh
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Đăng ký thành công! Vui lòng đăng nhập."),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      // Xử lý lỗi từ Firebase
      String msg = "Đã có lỗi xảy ra";
      if (e.code == 'user-not-found') msg = "Không tìm thấy tài khoản này.";
      else if (e.code == 'wrong-password') msg = "Sai mật khẩu.";
      else if (e.code == 'email-already-in-use') msg = "Email này đã được đăng ký.";
      else if (e.code == 'weak-password') msg = "Mật khẩu quá yếu (cần >6 ký tự).";
      else if (e.code == 'invalid-email') msg = "Email không hợp lệ.";
      else if (e.code == 'password-mismatch') msg = "Mật khẩu xác nhận không khớp.";

      setState(() => errorMessage = msg);
    } catch (e) {
      setState(() => errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Nền tối
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. ICON VÀ TIÊU ĐỀ
              Icon(
                  isLogin ? Icons.lock_open_rounded : Icons.person_add_rounded,
                  size: 80,
                  color: const Color(0xFF32C5FF)
              ),
              const SizedBox(height: 20),
              Text(
                isLogin ? "ĐĂNG NHẬP" : "ĐĂNG KÝ",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                isLogin ? "Chào mừng bạn quay lại!" : "Tạo tài khoản mới ngay",
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 40),

              // 2. FORM NHẬP LIỆU
              _buildTextField(_emailController, "Email", Icons.email_outlined),
              const SizedBox(height: 16),
              _buildTextField(_passwordController, "Mật khẩu", Icons.lock_outline, isObscure: true),

              // Chỉ hiện ô Nhập lại mật khẩu khi Đăng Ký
              if (!isLogin) ...[
                const SizedBox(height: 16),
                _buildTextField(_confirmController, "Nhập lại mật khẩu", Icons.lock_reset, isObscure: true),
              ],

              const SizedBox(height: 12),

              // 3. HIỂN THỊ LỖI
              if (errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // 4. NÚT SUBMIT
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF32C5FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                    isLogin ? "ĐĂNG NHẬP" : "ĐĂNG KÝ NGAY",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 5. NÚT CHUYỂN ĐỔI (TOGGLE)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLogin ? "Chưa có tài khoản? " : "Đã có tài khoản? ",
                    style: const TextStyle(color: Colors.white54),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isLogin = !isLogin; // Đảo ngược trạng thái
                        errorMessage = null; // Xóa lỗi cũ
                        _confirmController.clear(); // Xóa mật khẩu cũ
                        _passwordController.clear();
                      });
                    },
                    child: Text(
                      isLogin ? "Đăng ký" : "Đăng nhập",
                      style: const TextStyle(color: Color(0xFF32C5FF), fontWeight: FontWeight.bold),
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

  // Widget con để vẽ ô nhập liệu
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isObscure = false}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF32C5FF))),
        prefixIcon: Icon(icon, color: Colors.white54),
      ),
    );
  }
}
