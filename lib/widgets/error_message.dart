import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../services/immich_service.dart';

String immichErrorMessage(BuildContext context, Object error) {
  final l = context.l10n;
  if (error is ImmichConnectionException) {
    return switch (error.error) {
      ImmichConnectionError.unreachable => l.t('immichUnreachable'),
      ImmichConnectionError.timeout => l.t('immichTimeout'),
      ImmichConnectionError.server => l.t('immichServerError', {
          'code': error.statusCode ?? 500,
        }),
    };
  }
  return error.toString().replaceFirst('Bad state: ', '');
}
