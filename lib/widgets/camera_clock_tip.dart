import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class CameraClockTip extends StatelessWidget {
  const CameraClockTip({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return AppSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showClockSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.yellowSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: AppTheme.warning,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.t('cameraTimeTipTitle'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.t('cameraTimeTipCompact'),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showClockSheet(BuildContext context) {
    final l = context.l10n;

    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('cameraTimeTipTitle'),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.t('cameraTimeTipBody'),
              style: const TextStyle(
                color: AppTheme.muted,
                height: 1.45,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            const _PhoneClock(),
          ],
        ),
      ),
    );
  }
}

class _PhoneClock extends StatefulWidget {
  const _PhoneClock();

  @override
  State<_PhoneClock> createState() => _PhoneClockState();
}

class _PhoneClockState extends State<_PhoneClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() => _now = DateTime.now());
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _utcOffset(Duration offset) {
    final negative = offset.isNegative;
    final absolute = offset.abs();
    final hours = absolute.inHours;
    final minutes = absolute.inMinutes.remainder(60);
    return 'UTC${negative ? '-' : '+'}${_twoDigits(hours)}:${_twoDigits(minutes)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final time =
        '${_twoDigits(_now.hour)}:${_twoDigits(_now.minute)}:${_twoDigits(_now.second)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.yellowSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.brandYellow.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.phone_android_rounded,
            size: 20,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('phoneTime'),
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_now.timeZoneName} · ${_utcOffset(_now.timeZoneOffset)}',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
