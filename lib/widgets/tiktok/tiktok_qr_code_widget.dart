import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TikTokQRCodeWidget extends StatelessWidget {
  final String qrData;
  final String status;
  final VoidCallback onRefresh;
  final VoidCallback? onCancel;

  const TikTokQRCodeWidget({
    Key? key,
    required this.qrData,
    required this.status,
    required this.onRefresh,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code, color: Colors.black),
                const SizedBox(width: 8),
                Text(
                  'مسح رمز QR باستخدام تطبيق تيك توك',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildQRCode(),
            const SizedBox(height: 16),
            _buildStatusWidget(context),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onCancel != null && status != 'confirmed')
                  OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel),
                    label: const Text('إلغاء'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                if (status == 'expired') const SizedBox(width: 16),
                if (status == 'expired')
                  ElevatedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث الرمز'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCode() {
    // إذا كان يبدأ بـ aweme://، نحوله إلى بيانات معلومات
    final qrContent = qrData.startsWith('aweme://')
        ? 'افتح تطبيق تيك توك وانتقل إلى الإعدادات > المزيد > امسح الرمز'
        : qrData;

    // عرض رمز QR بناءً على الحالة
    switch (status) {
      case 'new':
      case 'scanned':
        // عرض رمز QR فقط إذا كان عنوان URL كاملًا
        if (qrData.startsWith('aweme://')) {
          return Container(
            width: 240,
            height: 240,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(4),
              embeddedImage: const AssetImage('assets/images/tiktok_logo.png'),
              embeddedImageStyle: const QrEmbeddedImageStyle(
                size: Size(40, 40),
              ),
            ),
          );
        } else {
          // إذا كانت البيانات ليست عنوان URL كاملًا، اعرض صورة QR
          // من البيانات إذا كانت في تنسيق base64
          if (qrData.contains('base64')) {
            try {
              final imageData =
                  qrData.replaceAll(RegExp(r'data:image/\w+;base64,'), '');
              return Container(
                width: 240,
                height: 240,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Image.memory(
                  base64Decode(imageData),
                  width: 220,
                  height: 220,
                ),
              );
            } catch (e) {
              return const Center(
                child: Text('خطأ في عرض رمز QR'),
              );
            }
          } else {
            // إذا لم يكن هناك بيانات صالحة، اعرض رسالة خطأ
            return const Center(
              child: Text('لا يوجد بيانات رمز QR صالحة'),
            );
          }
        }

      case 'confirmed':
        return Container(
          width: 240,
          height: 240,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
                SizedBox(height: 16),
                Text(
                  'تم المصادقة بنجاح!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        );

      case 'expired':
        return Container(
          width: 240,
          height: 240,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.timer_off,
                  color: Colors.red,
                  size: 80,
                ),
                SizedBox(height: 16),
                Text(
                  'انتهت صلاحية الرمز',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        );

      default:
        // في أي حالة أخرى، اعرض رسالة جاري التحميل
        return Container(
          width: 240,
          height: 240,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
    }
  }

  Widget _buildStatusWidget(BuildContext context) {
    Color color;
    IconData icon;
    String message;

    switch (status) {
      case 'new':
        color = Colors.blue;
        icon = Icons.qr_code;
        message = 'جاهز للمسح';
        break;
      case 'scanned':
        color = Colors.orange;
        icon = Icons.phone_android;
        message = 'تم المسح، يرجى التأكيد في التطبيق';
        break;
      case 'confirmed':
        color = Colors.green;
        icon = Icons.check_circle;
        message = 'تم المصادقة بنجاح!';
        break;
      case 'expired':
        color = Colors.red;
        icon = Icons.timer_off;
        message = 'انتهت صلاحية الرمز';
        break;
      case 'utilised':
        color = Colors.grey;
        icon = Icons.done_all;
        message = 'تم استخدام الرمز بالفعل';
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
        message = 'جاري التحميل...';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
