class AppConfig {
  static const String appName = 'مدير منصات التواصل الاجتماعي';

  // Facebook Configuration
  static const String facebookAppId = 'YOUR_FACEBOOK_APP_ID';
  static const String facebookClientToken = 'YOUR_FACEBOOK_CLIENT_TOKEN';
  static const String graphApiVersion = 'v18.0';
  static const String baseUrl = 'https://graph.facebook.com/$graphApiVersion';

  // Maytapi WhatsApp Configuration
  static const String maytapiProductId = 'f7da023e-da13-48eb-812e-a745739944cd';
  static const String maytapiApiKey = '3e863062-6f04-4f1e-b3db-640a7133c732';
  static const String maytapiDefaultPhoneId = '77976';
  // Storage Keys
  static const String tokenKey = 'fb_access_token';
  static const String userDataKey = 'user_data';
  static const String selectedPagesKey = 'selected_pages';
  static const String whatsappConnectionKey = 'whatsapp_connection_status';
  static const String maytapiPhoneIdKey = 'whatsapp_phone_id';

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
