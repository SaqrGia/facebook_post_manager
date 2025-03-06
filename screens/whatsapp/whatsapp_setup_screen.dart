import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/whatsapp_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../config/app_config.dart';

class WhatsAppSetupScreen extends StatefulWidget {
  const WhatsAppSetupScreen({Key? key}) : super(key: key);

  @override
  State<WhatsAppSetupScreen> createState() => _WhatsAppSetupScreenState();
}

class _WhatsAppSetupScreenState extends State<WhatsAppSetupScreen> {
  bool _isCheckingStatus = false;
  bool _useDirectUrl = true; // استخدام رابط مباشر لصورة QR

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    setState(() => _isCheckingStatus = true);

    final provider = context.read<WhatsAppProvider>();
    final isConnected = await provider.checkConnection();

    if (!mounted) return;

    if (isConnected) {
      // إذا كان متصلاً، انتقل إلى الشاشة الرئيسية أو جلب المجموعات
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('متصل بواتساب بالفعل!'),
          backgroundColor: Colors.green,
        ),
      );
      provider.loadGroups();

      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      // إذا لم يكن متصلاً، احصل على رمز QR
      await provider.getQRCode();
    }

    if (mounted) {
      setState(() => _isCheckingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعداد واتساب'),
        actions: [
          // عرض زر تبديل طريقة عرض QR
          IconButton(
            icon: Icon(_useDirectUrl ? Icons.qr_code : Icons.image),
            onPressed: () {
              setState(() {
                _useDirectUrl = !_useDirectUrl;
              });
            },
            tooltip:
                _useDirectUrl ? 'تبديل لوضع QR المباشر' : 'تبديل لرابط الصورة',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة تشغيل العميل',
            onPressed: () async {
              final provider = context.read<WhatsAppProvider>();
              await provider.restartClient();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تمت إعادة تشغيل العميل، انتظر رمز QR جديد'),
                  ),
                );
              }
              // عد للتحقق بعد فترة
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted) {
                  provider.getQRCode();
                }
              });
            },
          ),
        ],
      ),
      body: _isCheckingStatus
          ? const Center(
              child:
                  LoadingIndicator(message: 'جاري التحقق من حالة الاتصال...'))
          : Consumer<WhatsAppProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(
                      child: LoadingIndicator(message: 'جاري جلب رمز QR...'));
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'حدث خطأ: ${provider.error}',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => provider.getQRCode(),
                              child: const Text('إعادة المحاولة'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => provider.restartClient(),
                              child: const Text('إعادة تشغيل العميل'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                // التحقق من أن لدينا على الأقل رمز QR أو صورة QR
                if (provider.qrCode == null && !_useDirectUrl) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'لم يتم العثور على رمز QR.\nيرجى إعادة تشغيل العميل أو الانتظار لحظات.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.getQRCode(),
                          child: const Text('تحديث'),
                        ),
                      ],
                    ),
                  );
                }

                // عرض رمز QR
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'مسح رمز QR باستخدام واتساب',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'افتح واتساب على هاتفك > انقر على النقاط الثلاث > واتساب ويب > مسح الرمز',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border:
                                Border.all(color: Colors.grey.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: _useDirectUrl
                              // استخدام رابط مباشر للصورة QR
                              ? Image.network(
                                  provider.getQRImageUrl(),
                                  width: 250,
                                  height: 250,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('خطأ في تحميل الصورة: $error');
                                    return Column(
                                      children: [
                                        const Icon(Icons.error,
                                            color: Colors.red, size: 48),
                                        const SizedBox(height: 8),
                                        const Text('فشل تحميل صورة QR',
                                            textAlign: TextAlign.center),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _useDirectUrl = false;
                                            });
                                          },
                                          child:
                                              const Text('جرب الطريقة الثانية'),
                                        ),
                                      ],
                                    );
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return SizedBox(
                                      width: 250,
                                      height: 250,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              // استخدام QrImage من نص مباشر
                              : (provider.qrCode != null
                                  ? QrImageView(
                                      data: provider.qrCode!,
                                      version: QrVersions.auto,
                                      size: 250.0,
                                      backgroundColor: Colors.white,
                                    )
                                  : const SizedBox(
                                      width: 250,
                                      height: 250,
                                      child: Center(
                                        child: Text('رمز QR غير متاح حاليًا'),
                                      ),
                                    )),
                        ),
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'هذا الرمز صالح لمرة واحدة فقط وسينتهي خلال دقيقة واحدة',
                            style: TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                provider.getQRCode();
                                // تحديث الصفحة لتحميل صورة QR الجديدة
                                if (_useDirectUrl) {
                                  setState(() {});
                                }
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('تحديث الرمز'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _checkConnectionStatus,
                              icon: const Icon(Icons.check_circle),
                              label: const Text('التحقق من الاتصال'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
