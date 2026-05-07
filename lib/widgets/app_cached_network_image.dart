import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

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
    return PremiumImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
    );
  }
}

class PremiumImage extends StatelessWidget {
  const PremiumImage({
    required this.imageUrl,
    super.key,
    this.fit,
    this.width,
    this.height,
    this.borderRadius,
    this.memCacheWidth = 500,
  });

  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final int memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final resolved = imageUrl.trim();
    Widget content;

    if (resolved.isEmpty) {
      content = const _ImageShimmerPlaceholder();
    } else if (resolved.startsWith('assets/')) {
      content = Image.asset(
        resolved,
        fit: fit,
        width: width,
        height: height,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return const _ImageShimmerPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) =>
            const _EmeraldErrorPlaceholder(),
      );
    } else {
      content = CachedNetworkImage(
        imageUrl: resolved,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: memCacheWidth,
        placeholder: (context, url) => const _ImageShimmerPlaceholder(),
        errorWidget: (context, url, error) => const _EmeraldErrorPlaceholder(),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: content);
    }

    return content;
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
          child: PremiumImage(
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

class _ImageShimmerPlaceholder extends StatelessWidget {
  const _ImageShimmerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFD9E6DF),
      highlightColor: const Color(0xFFF7FBF9),
      child: Container(color: Colors.white),
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
