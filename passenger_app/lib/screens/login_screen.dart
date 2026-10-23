import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController(text: 'Abhinav');
  final TextEditingController _contactCtrl = TextEditingController(text: '9847123456');
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _performLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService().login(
        name: _nameCtrl.text.trim(),
        phoneOrEmail: _contactCtrl.text.trim(),
      );

      final user = res['user'] as Map<String, dynamic>;
      UserSession().setUser(
        id: user['id'] as int? ?? 1,
        name: user['name'] as String? ?? _nameCtrl.text.trim(),
        contact: user['phone_or_email'] as String? ?? _contactCtrl.text.trim(),
      );

      if (mounted) {
        widget.onLoginSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _quickDemoLogin() {
    _nameCtrl.text = 'Demo Passenger';
    _contactCtrl.text = '9998887776';
    _performLogin();
  }

  void _showServerConfigDialog() {
    final urlCtrl = TextEditingController(text: ApiService().baseUrl);
    bool testing = false;
    String? statusMsg;
    bool isSuccess = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
          ),
          title: const Row(
            children: [
              Icon(Icons.wifi_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Text('Backend Server IP', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter backend API URL (e.g. current Wi-Fi IP or Render URL):',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  hintText: 'http://10.242.209.133:5000/api',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                ),
              ),
              if (statusMsg != null) ...[
                const SizedBox(height: 10),
                Text(
                  statusMsg!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSuccess ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: testing
                  ? null
                  : () async {
                      setDialogState(() {
                        testing = true;
                        statusMsg = 'Testing connection...';
                      });
                      ApiService().updateBaseUrl(urlCtrl.text);
                      final ok = await ApiService().checkHealth();
                      setDialogState(() {
                        testing = false;
                        isSuccess = ok;
                        statusMsg = ok ? '✓ Connected successfully!' : '✗ Failed to reach server. Check IP & port.';
                      });
                    },
              child: const Text('Test Connection', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                ApiService().updateBaseUrl(urlCtrl.text);
                Navigator.of(ctx).pop();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Updated backend URL to: ${ApiService().baseUrl}')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            tooltip: 'Configure Backend IP',
            onPressed: _showServerConfigDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon & Brand (Orange + Train)
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.train_rounded, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Ente Theevandi',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Real-Time Passenger Crowd & Coach Positioning',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 32),

                  // Login Form Card (Sleek Dark Container)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.cardBorder, width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Passenger Sign In',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Enter your details to track trains and share crowd votes',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 20),

                          // Name Field
                          const Text('Full Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'e.g. Abhinav Kumar',
                              prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: AppColors.textSecondary),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Please enter your name';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Phone or Email Field
                          const Text('Mobile Number / Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _contactCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'e.g. 9847123456 or user@rail.com',
                              prefixIcon: Icon(Icons.phone_android_rounded, size: 20, color: AppColors.textSecondary),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Please enter your mobile or email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF241414),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF5A2222)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, size: 18, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),

                          // Submit Button (Vibrant Electric Orange)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _performLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Sign In & Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Demo One-Click Sign In
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _quickDemoLogin,
                              icon: const Icon(Icons.bolt_rounded, size: 18, color: AppColors.primaryLight),
                              label: const Text('Quick Presentation Sign In', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryLight)),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.surface,
                                side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Server URL Quick Config Button
                          InkWell(
                            onTap: _showServerConfigDialog,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.dns_outlined, size: 13, color: AppColors.textTertiary),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Server: ${ApiService().baseUrl.replaceAll("http://", "")}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, decoration: TextDecoration.underline),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 11, color: AppColors.textTertiary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mini Footer info
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: AppColors.textTertiary),
                      SizedBox(width: 5),
                      Text('Database connected • GPS Coach Estimation Engine', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                    ],
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
