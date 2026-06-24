import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/providers.dart';

class ContentCover extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final direction = ref.watch(designDirectionProvider);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(gradient: AppTokens.coverGradient(direction)),
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
