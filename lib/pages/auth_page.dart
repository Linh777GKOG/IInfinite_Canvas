import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String? errorMessage;
  bool isLoading = false;

  // 🔥 HÀM XỬ LÝ QUÊN MẬT KHẨU (Mới)
  Future<void> _forgotPassword() async {
    final resetEmailController = TextEditingController(text: _emailController.text);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C), // Màu nền tối cho hợp theme
        title: const Text("Đặt lại mật khẩu", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Nhập email của bạn, chúng tôi sẽ gửi đường dẫn đặt lại mật khẩu.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Email",
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) return;

              try {
                // Gửi email reset từ Firebase
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) {
                  Navigator.pop(context); // Đóng hộp thoại
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Đã gửi email! Hãy kiểm tra hòm thư của bạn."),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                // Xử lý lỗi nếu email không tồn tại
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Lỗi: ${e.message}"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Gửi", style: TextStyle(color: Color(0xFF32C5FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (isLogin) {
        await AuthService().signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        if (_passwordController.text != _confirmController.text) {
          throw FirebaseAuthException(code: 'password-mismatch', message: "Mật khẩu xác nhận không khớp");
        }
        await AuthService().signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          setState(() {
            isLogin = true;
            errorMessage = null;
            _passwordController.clear();
            _confirmController.clear();
          });
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
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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

              _buildTextField(_emailController, "Email", Icons.email_outlined),
              const SizedBox(height: 16),
              _buildTextField(_passwordController, "Mật khẩu", Icons.lock_outline, isObscure: true),

              if (!isLogin) ...[
                const SizedBox(height: 16),
                _buildTextField(_confirmController, "Nhập lại mật khẩu", Icons.lock_reset, isObscure: true),
              ],

              // 🔥 NÚT QUÊN MẬT KHẨU (Chỉ hiện khi Đăng Nhập)
              if (isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text(
                        "Quên mật khẩu?",
                        style: TextStyle(color: Color(0xFF32C5FF), fontWeight: FontWeight.bold)
                    ),
                  ),
                )
              else
                const SizedBox(height: 20), // Khoảng cách bù khi không có nút quên pass

              if (errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),

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
                        isLogin = !isLogin;
                        errorMessage = null;
                        _confirmController.clear();
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