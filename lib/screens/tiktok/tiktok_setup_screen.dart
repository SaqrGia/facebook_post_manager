import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tiktok_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/tiktok/tiktok_qr_code_widget.dart';
import '../../models/tiktok_account.dart';
import 'tiktok_manual_setup_screen.dart';

/// شاشة إعداد TikTok
///
/// تستخدم للربط مع حسابات TikTok باستخدام مسح رمز QR
class TikTokSetupScreen extends StatefulWidget {
  const TikTokSetupScreen({Key? key}) : super(key: key);

  @override
  State<TikTokSetupScreen> createState() => _TikTokSetupScreenState();
}

class _TikTokSetupScreenState extends State<TikTokSetupScreen> {
  @override
  void initState() {
    super.initState();
    // طلب رمز QR تلقائيًا عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initQRCode();
    });
  }

  // طلب رمز QR وبدء الاستطلاع
  Future<void> _initQRCode() async {
    final provider = context.read<TikTokProvider>();
    final success = await provider.requestQRCode();

    if (success && mounted) {
      // بدء استطلاع حالة رمز QR
      provider.startQRPolling();
    }
  }

  @override
  void dispose() {
    // نظيف - يتم التعامل مع إيقاف الاستطلاع في dispose لـ TikTokProvider
    super.dispose();
  }

  // دالة جديدة لعرض خيار الربط اليدوي بشكل دائم
  Widget _buildManualSetup() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ربط الحساب يدويًا',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'إذا كان لديك رمز الوصول، يمكنك إدخاله مباشرة دون الحاجة لمسح رمز QR',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TikTokManualSetupScreen(),
                    ),
                  ).then((result) {
                    if (result == true) {
                      // إذا نجح الربط اليدوي، نعود إلى الشاشة السابقة
                      Navigator.pop(context);
                    }
                  });
                },
                icon: const Icon(Icons.edit),
                label: const Text('إدخال رمز الوصول يدويًا'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعداد تيك توك'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // إضافة قسم الربط اليدوي في بداية الشاشة
            _buildManualSetup(),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // عرض الحسابات المرتبطة حاليًا
            _buildLinkedAccounts(),
            const SizedBox(height: 24),
            // مكون رمز QR
            _buildQRCode(),
            const SizedBox(height: 24),
            // تعليمات إضافية
            _buildInstructions(),
          ],
        ),
      ),
    );
  }

  // عرض الحسابات المرتبطة حاليًا
  Widget _buildLinkedAccounts() {
    return Consumer<TikTokProvider>(
      builder: (context, provider, _) {
        final accounts = provider.accounts;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الحسابات المرتبطة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (accounts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'لا توجد حسابات مرتبطة',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              )
            else
              ...accounts.map((account) => _buildAccountCard(account)),
          ],
        );
      },
    );
  }

  // بطاقة عرض حساب فردي
  Widget _buildAccountCard(TikTokAccount account) {
    return Consumer<TikTokProvider>(
      builder: (context, provider, _) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: account.avatarUrl != null
                ? CircleAvatar(
                    backgroundImage: NetworkImage(account.avatarUrl!),
                    backgroundColor: Colors.black,
                  )
                : CircleAvatar(
                    backgroundColor: Colors.black,
                    child: Text(
                      account.username.isNotEmpty
                          ? account.username[0].toUpperCase()
                          : 'T',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            title: Text('@${account.username}'),
            subtitle: account.isTokenExpired
                ? Row(
                    children: const [
                      Icon(Icons.error_outline, color: Colors.red, size: 16),
                      SizedBox(width: 4),
                      Text('انتهت صلاحية الرمز - انقر للتحديث',
                          style: TextStyle(color: Colors.red)),
                    ],
                  )
                : Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text('حساب نشط', style: TextStyle(color: Colors.green)),
                    ],
                  ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'refresh') {
                  // تحديث الحساب
                  final success = await provider.refreshAccountInfo(account.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? 'تم تحديث الحساب بنجاح'
                            : 'فشل تحديث الحساب'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                } else if (value == 'remove') {
                  // إزالة الحساب
                  _confirmRemoveAccount(context, account, provider);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'refresh',
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('تحديث الحساب'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'remove',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('إزالة الحساب',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // تأكيد إزالة الحساب
  Future<void> _confirmRemoveAccount(
    BuildContext context,
    TikTokAccount account,
    TikTokProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة الحساب'),
        content:
            Text('هل أنت متأكد من رغبتك في إزالة حساب @${account.username}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إزالة', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.removeAccount(account.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إزالة الحساب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // عرض رمز QR
  Widget _buildQRCode() {
    return Consumer<TikTokProvider>(
      builder: (context, provider, _) {
        // عرض مؤشر التحميل أثناء جلب البيانات
        if (provider.isLoading) {
          return const Center(
            child: LoadingIndicator(message: 'جاري تحميل رمز QR...'),
          );
        }

        if (provider.error != null) {
          return Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initQRCode,
                    child: const Text('إعادة المحاولة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // إذا كان هناك رمز QR، اعرضه
        if (provider.qrCodeUrl != null) {
          return TikTokQRCodeWidget(
            qrData: provider.qrCodeUrl!,
            status: provider.qrStatus,
            onRefresh: _initQRCode,
            onCancel: () {
              // توقف عن استطلاع الحالة
              // لا نحتاج لاستدعاء stopQRPolling هنا - سيتم التعامل معه في الـ Provider
              setState(() {});
            },
          );
        }

        // إذا لم يكن هناك رمز QR، اعرض زر الطلب
        return Center(
          child: Column(
            children: [
              const Text(
                'اربط حساب تيك توك الخاص بك باستخدام رمز QR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _initQRCode,
                icon: const Icon(Icons.qr_code),
                label: const Text('طلب رمز QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 12), // مسافة بين الزرين
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TikTokManualSetupScreen(),
                    ),
                  ).then((result) {
                    if (result == true) {
                      // إذا نجح الربط اليدوي، نعود إلى الشاشة السابقة
                      Navigator.pop(context);
                    }
                  });
                },
                icon: const Icon(Icons.edit),
                label: const Text('إدخال رمز الوصول يدويًا'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // تعليمات إضافية
  Widget _buildInstructions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'كيفية ربط حساب تيك توك',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            _InstructionStep(
              number: '1',
              text: 'افتح تطبيق تيك توك على هاتفك',
            ),
            _InstructionStep(
              number: '2',
              text: 'انتقل إلى صفحة الملف الشخصي',
            ),
            _InstructionStep(
              number: '3',
              text: 'اضغط على ثلاث نقاط ↑ ثم اختر "مسح الرمز"',
            ),
            _InstructionStep(
              number: '4',
              text: 'امسح رمز QR الظاهر هنا',
            ),
            _InstructionStep(
              number: '5',
              text: 'اتبع التعليمات على الشاشة للموافقة على الصلاحيات',
            ),
            SizedBox(height: 8),
            Text(
              'ملاحظة: رمز QR صالح لمدة 60 ثانية فقط. إذا انتهت صلاحيته، يمكنك طلب رمز جديد.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ويدجت خطوة التعليمات
class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionStep({
    Key? key,
    required this.number,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.black,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}
