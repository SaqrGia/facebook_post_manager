import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// ويدجت لعرض رمز QR الخاص بتيك توك
///
/// يعرض رمز QR للمصادقة ويعكس حالته الحالية
class TikTokQRCodeWidget extends StatelessWidget {
  /// بيانات رمز QR (URL أو نص)
  final String qrData;

  /// حالة رمز QR الحالية (new, scanned, confirmed, expired)
  final String status;

  /// دالة يتم استدعاؤها عند الضغط على زر التحديث
  final VoidCallback onRefresh;

  /// دالة يتم استدعاؤها عند الضغط على زر الإلغاء (اختيارية)
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
                      backgroundColor: Colors.black, // لون TikTok
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// بناء رمز QR بناءً على الحالة
  Widget _buildQRCode() {
    // عرض رمز QR بناءً على الحالة
    switch (status) {
      case 'new':
      case 'scanned':
        // إذا كانت البيانات URL كامل
        if (qrData.startsWith('http')) {
          return _buildQRImageView();
        }
        // إذا كانت البيانات تحتوي على base64 (صورة)
        else if (qrData.contains('base64')) {
          return _buildBase64Image();
        }
        // إذا كانت البيانات نصية بسيطة
        else {
          return _buildQRImageView();
        }

      case 'confirmed':
        return _buildConfirmedStatus();

      case 'expired':
        return _buildExpiredStatus();

      default:
        // حالة التحميل الافتراضية
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
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
        );
    }
  }

  /// بناء رمز QR باستخدام مكتبة QR Flutter
  Widget _buildQRImageView() {
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
  }

  /// بناء صورة من بيانات base64
  Widget _buildBase64Image() {
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
      return Container(
        width: 240,
        height: 240,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.error, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                'خطأ في عرض رمز QR',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// عرض حالة التأكيد
  Widget _buildConfirmedStatus() {
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
  }

  /// عرض حالة انتهاء الصلاحية
  Widget _buildExpiredStatus() {
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
  }

  /// بناء ويدجت عرض الحالة
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
      case 'used':
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
