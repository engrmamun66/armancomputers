import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Small square product image, falling back to a neutral placeholder icon
/// when the product has no image or it fails to load.
class ProductThumbnail extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;

  const ProductThumbnail({super.key, required this.url, this.size = 44, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Icon(Icons.image_outlined, size: size * 0.5, color: scheme.onSurfaceVariant),
    );

    if (url == null || url!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, _) => placeholder,
        errorWidget: (context, _, error) => placeholder,
      ),
    );
  }
}
