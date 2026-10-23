import 'package:flutter/material.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = UserSession();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings & Profile',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.3),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Profile Card
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            session.userName?.isNotEmpty == true ? session.userName![0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.userName ?? 'Demo Passenger',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              session.userContact ?? 'Connected',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          session.logout();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFF5A2222)),
                          backgroundColor: const Color(0xFF241414),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Sign Out', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // About Ente Theevandi Card (Backend Server Configuration Box Removed as requested!)
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'About Ente Theevandi',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ente Theevandi is a modern railway passenger monitoring platform designed to provide live coach crowd insights and platform coach alignment for Kerala rail transit.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                  ),
                  const Divider(height: 28, color: AppColors.cardBorder),
                  const Text('System Capabilities:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                  const SizedBox(height: 10),
                  _buildBullet('Platform Stop Division: Front & back coordinates divided into 25m coach parts.'),
                  _buildBullet('Anchor Passenger Kinematics: 4 passengers refreshed every 30s to detect departure.'),
                  _buildBullet('1-Minute Post-Departure Voting: Prompt asks for live crowd condition.'),
                  _buildBullet('Live Train Tracking: Real-time simulated GPS tracking and route path.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // App Version Info
          Center(
            child: Text(
              'Ente Theevandi • Version 2.0.0 (GPS Transit MVP)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 14)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
