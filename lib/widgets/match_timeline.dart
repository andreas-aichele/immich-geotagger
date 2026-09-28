import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// A shared visual explanation of how a photo time relates to saved GPS fixes.
class MatchTimeline extends StatelessWidget {
  const MatchTimeline({
    required this.photoTime,
    this.before,
    this.after,
    super.key,
  });

  final DateTime photoTime;
  final DateTime? before;
  final DateTime? after;

  @override
  Widget build(BuildContext context) {
    final localPhoto = photoTime.toLocal();
    final localBefore = before?.toLocal();
    final localAfter = after?.toLocal();
    final start = (localBefore ?? localPhoto).millisecondsSinceEpoch;
    final end = (localAfter ?? localPhoto).millisecondsSinceEpoch;
    final span = end - start;
    final photoRatio = before != null && after == null
        ? 1.0
        : before == null && after != null
        ? 0.0
        : span <= 0
        ? 0.5
        : ((localPhoto.millisecondsSinceEpoch - start) / span)
            .clamp(0.0, 1.0)
            .toDouble();

    String clock(DateTime value) => MaterialLocalizations.of(context)
        .formatTimeOfDay(
          TimeOfDay.fromDateTime(value),
          alwaysUse24HourFormat:
              MediaQuery.alwaysUse24HourFormatOf(context),
        );

    String date(DateTime value) =>
        MaterialLocalizations.of(context).formatShortDate(value);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const markerSize = 30.0;
          const iconSize = 22.0;
          const outerIconInset = (markerSize - iconSize) / 2;
          final width = constraints.maxWidth;
          final color = Theme.of(context).colorScheme.primary;
          final gpsBeforeX = markerSize / 2 - outerIconInset;
          final gpsAfterX = width - markerSize / 2 + outerIconInset;
          final intendedPhotoX =
              gpsBeforeX + (gpsAfterX - gpsBeforeX) * photoRatio;
          final minimumMarkerDistance = ((width - markerSize) / 3)
              .clamp(0.0, markerSize + 12)
              .toDouble();
          final photoX = before != null && after != null
              ? intendedPhotoX
                  .clamp(
                    gpsBeforeX + minimumMarkerDistance,
                    gpsAfterX - minimumMarkerDistance,
                  )
                  .toDouble()
              : intendedPhotoX;
          final lineStart = before != null
              ? gpsBeforeX
              : after != null
              ? photoX
              : null;
          final lineEnd = after != null
              ? gpsAfterX
              : before != null
              ? photoX
              : null;
          final surface = Theme.of(context).colorScheme.surface;

          Widget marker(IconData icon, Color iconColor) => Container(
                width: markerSize,
                height: markerSize,
                decoration: BoxDecoration(
                  color: surface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: iconSize, color: iconColor),
              );

          return Column(
            children: [
              SizedBox(
                height: 30,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    if (lineStart != null &&
                        lineEnd != null &&
                        lineEnd > lineStart)
                      Positioned(
                        left: lineStart,
                        top: 14,
                        width: lineEnd - lineStart,
                        child: Container(
                          height: 2,
                          color: AppTheme.muted.withValues(alpha: 0.45),
                        ),
                      ),
                    if (before != null)
                      Positioned(
                        left: -outerIconInset,
                        child: marker(
                          Icons.place_rounded,
                          const Color(0xFF157A4A),
                        ),
                      ),
                    if (after != null)
                      Positioned(
                        right: -outerIconInset,
                        child: marker(Icons.place_rounded, color),
                      ),
                    Positioned(
                      left: photoX - markerSize / 2,
                      child: marker(
                        Icons.photo_camera_rounded,
                        Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              _labels(
                context,
                before: localBefore,
                photo: localPhoto,
                after: localAfter,
                date: date,
                clock: clock,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _labels(
    BuildContext context, {
    required DateTime? before,
    required DateTime photo,
    required DateTime? after,
    required String Function(DateTime) date,
    required String Function(DateTime) clock,
  }) {
    final l = context.l10n;
    final photoAlignment = before != null && after != null
        ? TextAlign.center
        : before != null
        ? TextAlign.right
        : TextAlign.left;

    return SizedBox(
      height: 43,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (before != null)
            Expanded(
              child: _timeLabel(
                context,
                title: l.t('timelineGpsBefore'),
                dateTime: before,
                date: date,
                clock: clock,
                textAlign: TextAlign.left,
              ),
            ),
          Expanded(
            child: _timeLabel(
              context,
              title: l.t('timelinePhoto'),
              dateTime: photo,
              date: date,
              clock: clock,
              textAlign: photoAlignment,
            ),
          ),
          if (after != null)
            Expanded(
              child: _timeLabel(
                context,
                title: l.t('timelineGpsAfter'),
                dateTime: after,
                date: date,
                clock: clock,
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeLabel(
    BuildContext context, {
    required String title,
    required DateTime dateTime,
    required String Function(DateTime) date,
    required String Function(DateTime) clock,
    required TextAlign textAlign,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: const TextStyle(color: AppTheme.muted, fontSize: 10),
        ),
        Text(
          date(dateTime),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: const TextStyle(color: AppTheme.muted, fontSize: 10),
        ),
        Text(
          clock(dateTime),
          textAlign: textAlign,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
