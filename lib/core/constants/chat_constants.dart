class ChatConstants {
  static const int maxImageMb = 10;
  static const int maxVideoMb = 25;
  static const int maxVideoSeconds = 60;
  static const int maxMediaPerMessage = 10;
  static const int imageTargetMb = 1;
  static const int videoTargetMb = 10;
  static const int deleteForEveryoneWindowMinutes = 2880; // 48 hours
  static const int mediaUploadsPerHour = 60;
  static const int mediaRetentionDays = 90;

  static const List<String> supportedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
    'gif',
  ];

  static const List<String> supportedVideoExtensions = [
    'mp4',
    'mov',
    'webm',
    '3gp',
    'mkv',
    'm4v',
  ];
}
