class NotificationStrings {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'settings_title': 'Notification Settings',
      'alert_categories': 'Alert Categories',
      'messages': 'Messages',
      'messages_desc': 'Direct chat messages and conversation updates',
      'requests': 'Pet Match Requests',
      'requests_desc': 'Connection and meet-up requests from pet owners',
      'matches': 'Matches',
      'matches_desc': 'Mutual likes and newly confirmed pet matches',
      'orders': 'Orders & Shop',
      'orders_desc': 'Order confirmations, shipping updates, and cart alerts',
      'system': 'System & Announcements',
      'system_desc':
          'Account status changes, role approvals, and safety alerts',
      'display_privacy': 'Display & Privacy',
      'show_previews': 'Show Message Previews',
      'show_previews_desc':
          'Display sender name and message snippet in push notifications',
      'device_settings': 'Device & System Settings',
      'system_settings_title': 'Android System Notification Settings',
      'system_settings_desc': 'Configure system sound, vibration, lock screen visibility, and notification dots.',
      'permission_dialog_title': 'Stay Connected',
      'permission_dialog_body': 'Enable push notifications to get alerted about new pet matches, messages from owners, and updates about your pets.',
      'permission_not_now': 'Not Now',
      'permission_enable': 'Enable Notifications',
      'permission_denied_banner':
          'Notifications are off. You might miss new messages and pet matches.',
      'permission_dismiss': 'Dismiss',
      'update_failed': 'Failed to update notification settings. Reverted.',
      'new_message': 'New message',
      'photo': 'Photo',
      'video': 'Video',
      'photos_count': '{count} photos',
    },
    'ne': {
      'settings_title': 'सूचना सेटिङहरू',
      'alert_categories': 'सूचनाका प्रकारहरू',
      'messages': 'सन्देशहरू',
      'messages_desc': 'च्याट सन्देशहरू र कुराकानी अद्यावधिकहरू',
      'requests': 'पेट जोडी अनुरोधहरू',
      'requests_desc': 'अन्य पेट मालिकहरूबाट आएका अनुरोधहरू',
      'matches': 'जोडीहरू (Matches)',
      'matches_desc': 'नयाँ मिलेका पेट जोडीहरू',
      'orders': 'अर्डर र पसल',
      'orders_desc': 'अर्डर पुष्टि, डेलिभरी र कार्ट सूचनाहरू',
      'system': 'प्रणाली र घोषणाहरू',
      'system_desc': 'खाता स्थिति, अनुमोदन र सुरक्षा सूचनाहरू',
      'display_privacy': 'प्रदर्शन र गोपनीयता',
      'show_previews': 'सन्देश पूर्वावलोकन देखाउनुहोस्',
      'show_previews_desc': 'सूचनामा पठाउनेको नाम र सन्देशको अंश देखाउनुहोस्',
      'device_settings': 'उपकरण र प्रणाली सेटिङहरू',
      'system_settings_title': 'एन्ड्रोइड प्रणाली सूचना सेटिङहरू',
      'system_settings_desc':
          'ध्वनि, कम्पन, लक स्क्रिन र अन्य प्रणाली सेटिङहरू मिलाउनुहोस्।',
      'permission_dialog_title': 'सधैं जोडिनुहोस्',
      'permission_dialog_body': 'नयाँ पेट जोडी, च्याट सन्देशहरू र आफ्ना पेटका अद्यावधिकहरू पाउन सूचना सक्षम गर्नुहोस्।',
      'permission_not_now': 'अहिले होइन',
      'permission_enable': 'सूचना सक्षम गर्नुहोस्',
      'permission_denied_banner': 'सूचनाहरू बन्द छन्। तपाईंले नयाँ सन्देश र पेट जोडीहरू छुटाउन सक्नुहुन्छ।',
      'permission_dismiss': 'हटाउनुहोस्',
      'update_failed': 'सूचना सेटिङ अद्यावधिक गर्न असफल भयो। पूर्ववत् गरियो।',
      'new_message': 'नयाँ सन्देश',
      'photo': 'तस्बिर',
      'video': 'भिडियो',
      'photos_count': '{count} तस्बिरहरू',
    },
  };

  static String get(String key, {String locale = 'en'}) {
    final lang = locale.toLowerCase().startsWith('ne') ? 'ne' : 'en';
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
