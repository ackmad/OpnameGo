import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nikController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  bool _remember = true;

  Future<void> loginAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    final nik = nikController.text.trim();
    final password = passwordController.text.trim();

    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('nik', isEqualTo: nik)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('nik', nik);

        if (mounted) setState(() => _isLoading = false);
        // show success dialog then navigate when user taps Tutup
        final proceed = await _showResultDialog(true, 'Login Berhasil', 'Anda berhasil masuk');
        if (proceed == true && mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        await _showResultDialog(false, 'Login Gagal', 'NIK atau Password salah');
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      await _showResultDialog(false, 'Kesalahan', 'Terjadi kesalahan: $e');
    }
  }

  Future<bool?> _showResultDialog(bool success, String title, String message) {
    final mainColor = Colors.teal.shade700;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: success ? Colors.green.shade600 : Colors.red.shade600,
                    boxShadow: [
                      BoxShadow(
                        color: (success ? Colors.green : Colors.red).withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      success ? Icons.check : Icons.close,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(success),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showResetPasswordDialog() async {
    final _rk = GlobalKey<FormState>();
    final nikCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (c, setState) {
          return AlertDialog(
            title: const Text('Reset Password'),
            content: Form(
              key: _rk,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nikCtrl,
                      decoration: const InputDecoration(labelText: 'NIK'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan NIK' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email (opsional)'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: newPassCtrl,
                      decoration: const InputDecoration(labelText: 'Password baru'),
                      obscureText: true,
                      validator: (v) => v == null || v.trim().length < 4 ? 'Minimal 4 karakter' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: confirmCtrl,
                      decoration: const InputDecoration(labelText: 'Konfirmasi password'),
                      obscureText: true,
                      validator: (v) => v != newPassCtrl.text ? 'Password tidak cocok' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!_rk.currentState!.validate()) return;
                        setState(() => saving = true);
                        try {
                          final nik = nikCtrl.text.trim();
                          final email = emailCtrl.text.trim();
                          final newPass = newPassCtrl.text;

                          final snap = await FirebaseFirestore.instance
                              .collection('users')
                              .where('nik', isEqualTo: nik)
                              .limit(1)
                              .get();
                          if (snap.docs.isEmpty) {
                            if (mounted) _showMessage('NIK tidak ditemukan');
                            setState(() => saving = false);
                            return;
                          }

                          final doc = snap.docs.first;
                          final data = doc.data() as Map<String, dynamic>;
                          if (email.isNotEmpty && (data['email'] ?? '').toString().toLowerCase() != email.toLowerCase()) {
                            if (mounted) _showMessage('Email tidak cocok dengan NIK');
                            setState(() => saving = false);
                            return;
                          }

                          await FirebaseFirestore.instance.collection('users').doc(doc.id).update({
                            'password': newPass,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          if (mounted) _showMessage('Password berhasil direset');
                          Navigator.pop(ctx);
                        } catch (e) {
                          if (mounted) _showMessage('Gagal reset password: $e');
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                child: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Reset'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  void dispose() {
    nikController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({required String label, Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Colors.teal.shade700;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe6f4f2), Color(0xFFffffff)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Illustration
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: mainColor.withOpacity(0.08), shape: BoxShape.circle),
                        child: ClipOval(
                          child: SizedBox(
                            width: 110,
                            height: 110,
                            child: Image.asset(
                              'assets/logoStokOpname.png', // <-- ganti nama file sesuai logo Anda
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, size: 64, color: mainColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      Text(
                        'Sign in to OpNameGo',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: mainColor),
                      ),
                      const SizedBox(height: 8),
                      Text('Silakan masuk untuk mengelola stok', style: TextStyle(color: Colors.grey.shade700)),

                      const SizedBox(height: 20),

                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: nikController,
                              keyboardType: TextInputType.text,
                              decoration: _inputDecoration(label: 'NIK', prefix: const Icon(Icons.person, color: Colors.teal)),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan NIK' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: passwordController,
                              obscureText: _obscure,
                              decoration: _inputDecoration(
                                label: 'Password',
                                prefix: IconButton(
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.teal),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan password' : null,
                            ),
                            const SizedBox(height: 8),

                            // remember + forgot
                            Row(
                              children: [
                                Checkbox(
                                  value: _remember,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (v) => setState(() => _remember = v ?? true),
                                ),
                                const SizedBox(width: 6),
                                const Text('Ingat saya'),
                                const Spacer(),
                                TextButton(onPressed: _showResetPasswordDialog, child: const Text('Lupa Password?')),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Sign in button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : loginAdmin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mainColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 6,
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Color.fromARGB(255, 255, 255, 255), strokeWidth: 2.5))
                                    : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),

                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
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
