import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';

class AppCachedNetworkImage extends StatelessWidget {
  const AppCachedNetworkImage({
    required this.imageUrl,
    super.key,
    this.fit,
    this.width,
    this.height,
    this.memCacheWidth = 500,
  });

  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final int memCacheWidth;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      placeholder: (context, url) => const _EmeraldLoadingPlaceholder(),
      errorWidget: (context, url, error) => const _EmeraldErrorPlaceholder(),
    );
  }
}

class AppCachedAvatar extends StatelessWidget {
  const AppCachedAvatar({
    required this.imageUrl,
    required this.radius,
    super.key,
    this.backgroundColor = const Color(0xFFF3F5F4),
  });

  final String imageUrl;
  final double radius;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    if (imageUrl.trim().isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: const Icon(Icons.person_outline, color: Color(0xFF9AA6A0)),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: AppCachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: size,
            height: size,
          ),
        ),
      ),
    );
  }
}

class _EmeraldLoadingPlaceholder extends StatelessWidget {
  const _EmeraldLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F5F4),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }
}

class _EmeraldErrorPlaceholder extends StatelessWidget {
  const _EmeraldErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F5F4),
      child: const Center(
        child: Icon(Icons.person_outline, color: Color(0xFF9AA6A0), size: 34),
      ),
    );
  }
}
