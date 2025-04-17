import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tiktok_provider.dart';
import '../../config/app_config.dart';

class TikTokManualSetupScreen extends StatefulWidget {
  const TikTokManualSetupScreen({Key? key}) : super(key: key);

  @override
  State<TikTokManualSetupScreen> createState() =>
      _TikTokManualSetupScreenState();
}

class _TikTokManualSetupScreenState extends State<TikTokManualSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accessTokenController = TextEditingController();
  final _refreshTokenController = TextEditingController();
  final _expiresInController =
      TextEditingController(text: '86400'); // القيمة الافتراضية: 24 ساعة
  final _openIdController = TextEditingController(); // اختياري

  // إضافة قائمة بالنطاقات
  final List<String> _selectedScopes = [...AppConfig.tiktokPermissions];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _accessTokenController.dispose();
    _refreshTokenController.dispose();
    _expiresInController.dispose();
    _openIdController.dispose();
    super.dispose();
  }

  Future<void> _registerToken() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final provider = context.read<TikTokProvider>();

      // تحويل مدة الصلاحية إلى رقم صحيح
      int expiresIn = int.tryParse(_expiresInController.text) ?? 86400;

      // استدعاء طريقة المصادقة باستخدام الرمز الخارجي مع تمرير النطاقات
      final success = await provider.authenticateWithManualToken(
        accessToken: _accessTokenController.text,
        refreshToken: _refreshTokenController.text,
        expiresIn: expiresIn,
        openId: _openIdController.text.isEmpty ? null : _openIdController.text,
        scopes: _selectedScopes,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم ربط الحساب بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );

        // إغلاق الشاشة والعودة إلى الشاشة السابقة
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${provider.error ?? "خطأ غير معروف"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة حساب TikTok يدويًا'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // تعليمات محسنة مع التأكيد على النطاقات
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تعليمات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. استخدم Postman للحصول على رمز الوصول عبر عملية TikTok OAuth\n'
                        '2. تأكد من طلب النطاقات المطلوبة (المحددة أدناه) أثناء المصادقة\n'
                        '3. انسخ رمز الوصول (access_token) ورمز التحديث (refresh_token) من استجابة Postman\n'
                        '4. أدخل هذه الرموز في الحقول أدناه للربط مع حساب TikTok الخاص بك',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'النطاقات المطلوبة:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildScopesSection(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // حقل إدخال رمز الوصول (Access Token)
              TextFormField(
                controller: _accessTokenController,
                decoration: const InputDecoration(
                  labelText: 'رمز الوصول (Access Token)',
                  hintText: 'أدخل رمز الوصول الذي حصلت عليه من Postman',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال رمز الوصول';
                  }
                  return null;
                },
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // حقل إدخال رمز التحديث (Refresh Token)
              TextFormField(
                controller: _refreshTokenController,
                decoration: const InputDecoration(
                  labelText: 'رمز التحديث (Refresh Token)',
                  hintText: 'أدخل رمز التحديث (اختياري إذا لم يكن متوفرًا)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // حقل إدخال مدة الصلاحية (Expires In)
              TextFormField(
                controller: _expiresInController,
                decoration: const InputDecoration(
                  labelText: 'مدة الصلاحية بالثواني (Expires In)',
                  hintText: 'أدخل مدة صلاحية الرمز بالثواني',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال مدة الصلاحية';
                  }
                  if (int.tryParse(value) == null) {
                    return 'الرجاء إدخال رقم صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // حقل إدخال معرف المستخدم (اختياري)
              TextFormField(
                controller: _openIdController,
                decoration: const InputDecoration(
                  labelText: 'معرف المستخدم (Open ID) - اختياري',
                  hintText: 'سيتم استخراجه تلقائيًا إذا لم تدخله',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // زر الربط
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _registerToken,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          'ربط الحساب',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // إضافة قسم عرض النطاقات المطلوبة
  Widget _buildScopesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: AppConfig.tiktokPermissions.map((scope) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(
                scope,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getScopeDescription(scope),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // إضافة وصف لكل نطاق
  String _getScopeDescription(String scope) {
    switch (scope) {
      case 'user.info.basic':
        return '(معلومات المستخدم الأساسية)';
      case 'video.upload':
        return '(تحميل الفيديو)';
      default:
        return '';
    }
  }
}
