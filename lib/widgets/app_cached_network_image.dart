import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Widget hau irudiak kargatzeko eta cacheatzeko erabiltzen da.
///
/// Erabiltzen dena: `imageUrl` neurri eta `fit` bezalako aukera batzuk jasotzen ditu,
/// eta barruan `PremiumImage` erabiliz kargatze eta errore placeholder-ak kudeatzen ditu.
///
/// Parametroak:
/// - `imageUrl`: Kargatu beharreko irudiaren URLa edo lokaleko asset-aren path-a.
/// - `fit`: Irudiaren BoxFit balioaren menpe nola erakutsi.
/// - `width`, `height`: Erakusteko neurriak.
/// - `memCacheWidth`: CachedNetworkImage-rentzako memoriako zabalera gomendatua.
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
    // Hemen soilik `PremiumImage` delegatzen dugu, konfigurazio parametrizatuarekin.
    // Build metodo hau ez du egoera aldatzen, irudiaren aurrebista eta erroreak PremiumImage-k kudeatzen ditu.
    return PremiumImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
    );
  }
}

/// `PremiumImage` irudi bat erakusteko widget indartsuagoa da.
///
/// Helburua: asset edo urruneko irudia automatikoki hautatzea, placeholder-a (shimmer)
/// eta errore-ikusgarriak ematea. `borderRadius` ezarri daiteke ertzak mozteko.
///
/// Parametroak:
/// - `imageUrl`: asset edo URL bat ("assets/..." edo web URL).
/// - `borderRadius`: aurrez zehaztutako ertzak dituzten irudiak mozteko.
/// - `memCacheWidth`: CachedNetworkImage memcache konfigurazioa.
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

    // Baldintzak: hutsik den URL-a, asset lokal bat edo urruneko URL bat.
    if (resolved.isEmpty) {
      // URL hutsa bada, shimmer placeholder bat erakutsi — irudia kargatzen ari dela adierazteko.
      content = const _ImageShimmerPlaceholder();
    } else if (resolved.startsWith('assets/')) {
      // Lokaleko asset-a bada, `Image.asset` erabiliz erakutsi eta frameBuilder bidez placeholder-a mantendu kargatu arte.
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
      // Urruneko irudia denean, `CachedNetworkImage` erabiliz kargatu/cacheatu eta placeholder/error widget ematen dugu.
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

/// Avatar txiki bat erakusten duen widget-a, irudia badago `PremiumImage`-rekin erakusten du.
///
/// Parametroak:
/// - `imageUrl`: Avatar-entzako irudiaren URL-a edo asset path-a.
/// - `radius`: zirkuluaren erradioa (UI neurriak aldatzen ditu).
/// - `backgroundColor`: Avatar-aren aurreko kolorea hutsune baldintzetan.
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
    // Hemen determinatzen dugu asset edo URL hutsaren kasuan ikono-generikoa erakutsi.
    if (imageUrl.trim().isEmpty) {
      // Irudi gabe, default pertsona ikonoa erakutsi eta ez da ezer kargatzen.
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

/// Shimmer placeholder txikia irudiak kargatzen diren bitartean erakusteko.
/// Exekutatzen den bitartean dekorazio sinple bat itxura dinamikoarekin.
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

/// Erroreak gertatzean erakusten den placeholder-a (adibidez, irudia ezin bada kargatu).
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
