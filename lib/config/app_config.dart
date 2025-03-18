class AppConfig {
  static const String appName = 'مدير منصات التواصل الاجتماعي';

  // Facebook Configuration
  static const String facebookAppId = 'YOUR_FACEBOOK_APP_ID';
  static const String facebookClientToken = 'YOUR_FACEBOOK_CLIENT_TOKEN';
  static const String graphApiVersion = 'v18.0';
  static const String baseUrl = 'https://graph.facebook.com/$graphApiVersion';

  // Maytapi WhatsApp Configuration
  static const String maytapiProductId = '2f3a3d9d-daa0-4fee-bf03-ddbd24b5ec11';
  static const String maytapiApiKey = '19b2fc8c-f002-484c-b874-476465db783a';
  static const String maytapiDefaultPhoneId = '76515';
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
