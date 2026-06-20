import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ContentCover extends StatelessWidget {
  const ContentCover({
    required this.path,
    this.fit = BoxFit.cover,
    this.borderRadius,
    super.key,
  });

  final String path;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: const SizedBox.expand(),
    );
    final Widget image;
    if (path.startsWith('http')) {
      image = CachedNetworkImage(
        imageUrl: path,
        fit: fit,
        placeholder: (context, url) => placeholder,
        errorWidget: (context, url, error) => placeholder,
      );
    } else if (path.endsWith('.svg')) {
      image = SvgPicture.asset(
        path,
        fit: fit,
        placeholderBuilder: (_) => placeholder,
      );
    } else {
      image = Image.asset(
        path,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: image,
    );
  }
}
