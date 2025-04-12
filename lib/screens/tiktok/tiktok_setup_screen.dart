import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tiktok_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/tiktok/tiktok_qr_code_widget.dart';
import '../../models/tiktok_account.dart';

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
    // إيقاف استطلاع QR عند إغلاق الشاشة
    context.read<TikTokProvider>().stopQRPolling();
    super.dispose();
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
              ...accounts
                  .map((account) => _buildAccountTile(account, provider)),
          ],
        );
      },
    );
  }

  // عنصر حساب واحد
  Widget _buildAccountTile(TikTokAccount account, TikTokProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: account.avatarUrl != null
            ? CircleAvatar(
                backgroundImage: NetworkImage(account.avatarUrl!),
                backgroundColor: Colors.black,
              )
            : const CircleAvatar(
                backgroundColor: Colors.black,
                child: Icon(Icons.person, color: Colors.white),
              ),
        title: Text('@${account.username}'),
        subtitle: Text(
          account.isTokenExpired
              ? 'انتهت صلاحية الرمز - انقر للتحديث'
              : 'حساب نشط',
          style: TextStyle(
            color: account.isTokenExpired ? Colors.red : Colors.green,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmRemoveAccount(context, account, provider),
        ),
      ),
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

    if (confirmed == true) {
      await provider.removeAccount(account.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إزالة الحساب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
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
                    onPressed: () => _initQRCode(),
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
            onRefresh: () => _initQRCode(),
            onCancel: () {
              provider.stopQRPolling();
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
                onPressed: () => _initQRCode(),
                icon: const Icon(Icons.qr_code),
                label: const Text('طلب رمز QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.black,
                child: Text('1', style: TextStyle(color: Colors.white)),
              ),
              title: Text('افتح تطبيق تيك توك على هاتفك'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.black,
                child: Text('2', style: TextStyle(color: Colors.white)),
              ),
              title:
                  Text('انتقل إلى صفحة الملف الشخصي > ثلاث نقاط > مسح الرمز'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.black,
                child: Text('3', style: TextStyle(color: Colors.white)),
              ),
              title: Text('امسح رمز QR الظاهر هنا'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.black,
                child: Text('4', style: TextStyle(color: Colors.white)),
              ),
              title: Text('اتبع التعليمات على الشاشة للموافقة على الصلاحيات'),
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
