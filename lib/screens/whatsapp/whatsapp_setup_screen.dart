import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/whatsapp_provider.dart';
import '../../widgets/common/loading_indicator.dart';

class WhatsAppSetupScreen extends StatefulWidget {
  const WhatsAppSetupScreen({Key? key}) : super(key: key);

  @override
  State<WhatsAppSetupScreen> createState() => _WhatsAppSetupScreenState();
}

class _WhatsAppSetupScreenState extends State<WhatsAppSetupScreen> {
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // تحميل البيانات الأولية
  Future<void> _loadInitialData() async {
    setState(() => _isCheckingStatus = true);

    final provider = context.read<WhatsAppProvider>();
    final isConnected = await provider.checkConnection();

    if (!mounted) return;

    if (isConnected) {
      // إظهار مؤشر مع رسالة مختلفة
      setState(() {
        _isCheckingStatus = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('متصل بواتساب بالفعل! جاري جلب المجموعات...'),
          backgroundColor: Colors.green,
        ),
      );

      // جلب المجموعات
      try {
        await provider.loadGroups(forceRefresh: true);

        if (!mounted) return;

        // التحقق من وجود مجموعات
        if (provider.groups.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم العثور على ${provider.groups.length} مجموعة'),
              backgroundColor: Colors.green,
            ),
          );

          // الرجوع للشاشة السابقة فقط إذا كان هناك مجموعات
          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          // إذا لم يكن هناك مجموعات، نبقى في شاشة الإعداد ونعرض رسالة
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('تم الاتصال ولكن لم يتم العثور على مجموعات في واتساب'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ أثناء جلب المجموعات: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // جلب رمز QR
      await provider.getQRCode();
    }

    if (mounted) {
      setState(() => _isCheckingStatus = false);
    }
  }

  // التحقق من حالة الاتصال
  Future<void> _checkConnectionStatus() async {
    setState(() => _isCheckingStatus = true);

    final provider = context.read<WhatsAppProvider>();
    final isConnected = await provider.checkConnection();

    if (!mounted) return;

    if (isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الاتصال بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );

      // إظهار مؤشر تحميل إضافي للمجموعات
      setState(() {
        _isCheckingStatus = true;
      });

      // جلب المجموعات مع تفعيل التحديث الإجباري
      try {
        await provider.loadGroups(forceRefresh: true);

        if (!mounted) return;

        // التحقق من وجود مجموعات
        if (provider.groups.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم العثور على ${provider.groups.length} مجموعة'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // إظهار تنبيه إذا لم يتم العثور على مجموعات
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'تم الاتصال بنجاح ولكن لم يتم العثور على مجموعات، تأكد من وجود مجموعات في واتساب'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }

        if (mounted) {
          // الرجوع للشاشة السابقة فقط إذا كان هناك مجموعات
          if (provider.groups.isNotEmpty) {
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم الاتصال ولكن حدث خطأ أثناء جلب المجموعات: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم الاتصال، تأكد من مسح رمز QR بشكل صحيح'),
          backgroundColor: Colors.orange,
        ),
      );
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

              // التحقق مرة أخرى بعد فترة
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
                          'افتح واتساب على هاتفك > الإعدادات > الأجهزة المرتبطة > ربط جهاز',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // عرض رمز QR
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
                          child: provider.qrCode != null
                              // استخدام نص QR إذا كان متاحاً
                              ? AspectRatio(
                                  aspectRatio: 1,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    width: 250,
                                    height: 250,
                                    child: Image.memory(
                                      const Base64Decoder().convert(
                                          provider.qrCode!.replaceAll(
                                              RegExp(r'data:image/\w+;base64,'),
                                              '')),
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Center(
                                          child: Text(
                                              'غير قادر على عرض QR من النص',
                                              textAlign: TextAlign.center,
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        );
                                      },
                                    ),
                                  ),
                                )
                              // محاولة تحميل صورة QR من URL
                              : Image.network(
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
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red)),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'تأكد من:\n- اتصال الإنترنت\n- إعدادات API في تكوين التطبيق\n- تأكد من تفعيل الخدمة في MayTapi',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: () => provider.getQRCode(),
                                          child: const Text('إعادة المحاولة'),
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
                                ),
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
                              onPressed: () => provider.getQRCode(),
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
