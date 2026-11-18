import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Helper to inject Cloudinary on-the-fly optimization and transformation parameters
/// (w_{width}, h_{height}, c_fill, f_auto, q_auto) only if the URL is a Cloudinary
/// asset and has not already been transformed.
String buildTransformedCloudinaryUrl(
  String url, {
  int? width,
  int? height,
  String crop = 'fill',
}) {
  if (!url.contains('cloudinary.com') || !url.contains('/upload/')) {
    return url;
  }

  // If URL already has transformation segment (e.g. contains c_fill, w_, f_auto), leave as-is
  if (url.contains('/upload/w_') ||
      url.contains('/upload/c_') ||
      url.contains('/upload/f_auto') ||
      url.contains('/upload/q_auto')) {
    return url;
  }

  final List<String> transformations = [];
  if (width != null && width > 0) {
    transformations.add('w_$width');
  }
  if (height != null && height > 0) {
    transformations.add('h_$height');
  }
  if (width != null || height != null) {
    transformations.add('c_$crop');
  }
  transformations.add('f_auto');
  transformations.add('q_auto');

  final transformSegment = '/upload/${transformations.join(',')}/';
  return url.replaceFirst('/upload/', transformSegment);
}

/// Reusable network image widget with caching, placeholder shimmers,
/// error handling, and automated Cloudinary transformations.
class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final IconData fallbackIcon;
  final String? fallbackInitials;
  final int? transformationWidth;
  final int? transformationHeight;
  final Color? backgroundColor;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.fallbackIcon = Icons.pets,
    this.fallbackInitials,
    this.transformationWidth,
    this.transformationHeight,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final validUrl = imageUrl != null && imageUrl!.trim().isNotEmpty && imageUrl!.startsWith('http');

    if (!validUrl) {
      return _buildFallback();
    }

    // Auto-calculate transformation sizes from widget width/height if not explicitly set
    final tWidth = transformationWidth ?? (width != null ? (width! * 2).round() : null);
    final tHeight = transformationHeight ?? (height != null ? (height! * 2).round() : null);
    final processedUrl = buildTransformedCloudinaryUrl(
      imageUrl!.trim(),
      width: tWidth,
      height: tHeight,
    );

    Widget imageWidget = CachedNetworkImage(
      imageUrl: processedUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: backgroundColor ?? AppColors.creamDark,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        if (kDebugMode) {
          debugPrint('[AppNetworkImage] ⚠️ Failed to load image from $url: $error');
        }
        return _buildFallback();
      },
    );

    if (shape == BoxShape.circle) {
      return ClipOval(child: imageWidget);
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.creamDark,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : borderRadius,
      ),
      child: Center(
        child: (fallbackInitials != null && fallbackInitials!.trim().isNotEmpty)
            ? Text(
                fallbackInitials!.trim()[0].toUpperCase(),
                style: TextStyle(
                  fontSize: (height != null ? height! * 0.42 : 16.0).clamp(11.0, 28.0).toDouble(),
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              )
            : Icon(
                fallbackIcon,
                size: (height != null ? height! * 0.45 : 24.0).clamp(16.0, 48.0).toDouble(),
                color: AppColors.primaryLight,
              ),
      ),
    );
  }
}

/// Specialized avatar widget for users and owners.
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? initials;
  final VoidCallback? onTap;
  final Border? border;

  const UserAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 20,
    this.initials,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
      ),
      child: AppNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        shape: BoxShape.circle,
        fallbackIcon: Icons.person_outline,
        fallbackInitials: initials,
        transformationWidth: (size * 2.5).round(),
        transformationHeight: (size * 2.5).round(),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatar,
      );
    }

    return avatar;
  }
}
