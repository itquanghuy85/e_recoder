import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_tokens.dart';
import 'media_repository.dart';

/// Rounded thumbnail with a neutral placeholder while loading or if no frame exists.
class VideoThumb extends ConsumerWidget {
  const VideoThumb({super.key, required this.uri, this.size = 72});
  final String uri;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final thumb = ref.watch(thumbnailProvider(uri));
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: c.surfaceContainerHighest,
          child: thumb.maybeWhen(
            data: (bytes) => bytes == null
                ? Icon(Icons.movie_outlined, color: c.onSurfaceVariant)
                : Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
