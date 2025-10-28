import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/admin_page.dart';

class CustomNavBar extends StatelessWidget {
  final Color primary;
  const CustomNavBar({super.key, this.primary = const Color(0xFF0E8A7A)});

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Yakin ingin keluar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Logout')),
        ],
      ),
    );
    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double barHeight = 90.0; // sedikit ditambah agar lega
    const double notchRadius = 28.0;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: barHeight,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // background dengan notch tengah
            Positioned.fill(
              top: 18,
              child: CustomPaint(
                painter: _NavPainter(
                  color: Colors.white,
                  shadowColor: Colors.black12,
                ),
              ),
            ),

            // item kiri dan kanan
            Positioned.fill(
              top: 24,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavItem(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Admin',
                      color: primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminPage()),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.logout,
                      label: 'Logout',
                      color: Colors.red.shade600,
                      onTap: () => _confirmLogout(context),
                    ),
                  ],
                ),
              ),
            ),

            // tombol tengah
            Positioned(
              top: 4,
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/tambah'),
                child: Container(
                  width: notchRadius * 2 + 10,
                  height: notchRadius * 2 + 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [primary, primary.withOpacity(0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavPainter extends CustomPainter {
  final Color color;
  final Color shadowColor;
  _NavPainter({required this.color, required this.shadowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double height = size.height;
    const double radius = 20;
    const double notchR = 30;
    final centerX = size.width / 2;

    final rect = Rect.fromLTWH(0, 0, size.width, height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));
    final pathBackground = Path()..addRRect(rrect);

    final circle = Path()..addOval(Rect.fromCircle(center: Offset(centerX, 8), radius: notchR));
    final finalPath = Path.combine(PathOperation.difference, pathBackground, circle);

    canvas.drawShadow(finalPath, shadowColor, 5.0, true);
    final paint = Paint()..color = color;
    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.teal,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // compact sizes to avoid overflow on small available heights
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: 70,
        // fix total vertical space so it never exceeds parent's constraints
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 2), // small top padding
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 4),
            // fixed height box for the label to guarantee no overflow
            SizedBox(
              height: 14,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
