import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import 'location_map.dart';

typedef ThumbnailLoader = Future<Uint8List> Function(String assetId);

class PhotoThumbnail extends StatelessWidget {
  const PhotoThumbnail({
    required this.assetId,
    required this.loader,
    this.size = 84,
    this.isVideo = false,
    this.duration,
    super.key,
  });

  final String assetId;
  final ThumbnailLoader? loader;
  final double size;
  final bool isVideo;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: loader?.call(assetId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Image.memory(
                  snapshot.data!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
                if (isVideo)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC000000),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          if (duration != null) ...[
                            const SizedBox(width: 2),
                            Text(
                              _formatDuration(duration!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _placeholder(
            const Icon(Icons.broken_image_outlined, color: AppTheme.muted),
          );
        }

        return _placeholder(
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _placeholder(Widget child) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

/// A photo-sized touch target with a compact, accessible selection indicator.
class SelectableThumbnail extends StatelessWidget {
  const SelectableThumbnail({
    required this.child,
    required this.selected,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final Widget child;
  final bool selected;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        checked: selected,
        button: true,
        onTap: () => onChanged(!selected),
        child: ExcludeSemantics(
          child: Stack(
            children: [
              child,
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(!selected),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              selected ? AppTheme.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppTheme.primary : Colors.white,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 4),
                      ],
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

Future<void> showPhotoLocationSheet(
  BuildContext context, {
  required String assetId,
  required String fileName,
  required double latitude,
  required double longitude,
  required String subtitle,
  required ThumbnailLoader? thumbnailLoader,
  bool isVideo = false,
  Duration? duration,
}) async {
  final point = LatLng(latitude, longitude);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  PhotoThumbnail(
                    assetId: assetId,
                    loader: thumbnailLoader,
                    size: 58,
                    isVideo: isVideo,
                    duration: duration,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: LocationMap(
                    center: point,
                    markers: [
                      Marker(
                        point: point,
                        width: 48,
                        height: 48,
                        child: const PhotoLocationMarker(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${latitude.toStringAsFixed(6)}, '
                '${longitude.toStringAsFixed(6)}',
                style: const TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class PhotoLocationMarker extends StatelessWidget {
  const PhotoLocationMarker({this.selected = true, this.count, super.key});

  final bool selected;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary : const Color(0xFF8A8A8A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 2),
            color: Color(0x33000000),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: count == null
          ? const Icon(Icons.perm_media_outlined, color: Colors.white, size: 20)
          : Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
