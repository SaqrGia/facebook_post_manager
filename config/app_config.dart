class AppConfig {
  static const String appName = 'مدير منصات التواصل الاجتماعي';

  // Facebook Configuration
  static const String facebookAppId = 'YOUR_FACEBOOK_APP_ID';
  static const String facebookClientToken = 'YOUR_FACEBOOK_CLIENT_TOKEN';

  // API Configuration
  static const String graphApiVersion = 'v18.0';
  static const String baseUrl = 'https://graph.facebook.com/$graphApiVersion';

  // WhatsApp Configuration
  // قم بتغيير هذا العنوان ليناسب عنوان IP الخاص بجهازك أو خادمك
  static const String whatsappServerUrl = 'http://16.16.236.183:3000';

  // Storage Keys
  static const String tokenKey = 'fb_access_token';
  static const String userDataKey = 'user_data';
  static const String selectedPagesKey = 'selected_pages';
  static const String whatsappConnectionKey = 'whatsapp_connection_status';

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
