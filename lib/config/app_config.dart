class AppConfig {
  static const String appName = 'مدير منصات التواصل الاجتماعي';

  // Facebook Configuration
  static const String facebookAppId = 'YOUR_FACEBOOK_APP_ID';
  static const String facebookClientToken = 'YOUR_FACEBOOK_CLIENT_TOKEN';
  static const String graphApiVersion = 'v18.0';
  static const String baseUrl = 'https://graph.facebook.com/$graphApiVersion';

  // Maytapi WhatsApp Configuration
  static const String maytapiProductId = '031cfc4d-5c90-4270-86ec-23c6125e23df';
  static const String maytapiApiKey = 'f96d4ee8-05eb-49a0-8fd9-cf40731367d9';
  static const String maytapiDefaultPhoneId = '83518';

  // TikTok Configuration
  static const String tiktokClientKey = 'sbawd7xakgmyt8g669';
  static const String tiktokClientSecret = 'MypxLqu31goKj7W7YSvnjVaYNDd6wxxI';

  // عنوان إعادة التوجيه - تأكد من تسجيله بالضبط هكذا في لوحة تحكم TikTok
  static const String tiktokRedirectUri =
      'https://saqrgia.github.io/tiktok-auth-callback';

  // عناوين تستخدم في مختلف مراحل المصادقة
  static const String tiktokAuthUrl =
      'https://www.tiktok.com/v2/auth/authorize';
  static const String tiktokApiBaseUrl = 'https://open.tiktokapis.com/v2';

  // يحتاج TikTok نطاق مختلف لطريقة مصادقة QR
  static const List<String> tiktokPermissions = [
    'user.info.basic',
    'video.upload',
    'video.publish'
  ];

  // Storage Keys
  static const String tiktokVideoPrivacyLevel = 'PUBLIC';
  static const bool isTikTokSandboxMode = true;
  static const String tokenKey = 'fb_access_token';
  static const String userDataKey = 'user_data';
  static const String selectedPagesKey = 'selected_pages';
  static const String whatsappConnectionKey = 'whatsapp_connection_status';
  static const String maytapiPhoneIdKey = 'whatsapp_phone_id';
  static const String tiktokAccountsKey = 'tiktok_accounts';

  // Required Permissions
  static const List<String> requiredPermissions = [
    'email',
    'pages_show_list',
    'pages_read_engagement',
    'pages_manage_posts',
    'instagram_basic',
    'instagram_content_publish',
  ];
}
