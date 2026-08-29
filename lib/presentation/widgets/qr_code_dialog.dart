/// QR code dialog — renders a `pokatuha://` URI as a QR code with copy and
/// share actions (V2 USER_DISCOVERY.md §2). Used for both profile QR
/// (`pokatuha://u/<id>`) and group invite QR (`pokatuha://g/<code>`).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/l10n/app_localizations.dart';

class QrCodeDialog extends StatelessWidget {
  const QrCodeDialog({
    super.key,
    required this.title,
    required this.uri,
    this.subtitle,
  });

  final String title;
  final String uri;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: DesignTokens.headline()),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.space2),
              Text(
                subtitle!,
                style: DesignTokens.caption(),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: DesignTokens.space4),
            Container(
              padding: const EdgeInsets.all(DesignTokens.space4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
              ),
              child: QrImageView(
                data: uri,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: DesignTokens.space3),
            SelectableText(
              uri,
              style: DesignTokens.caption(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: uri));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.copied)),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(l.copy),
                ),
                TextButton.icon(
                  onPressed: () => Share.share(uri),
                  icon: const Icon(Icons.share_rounded),
                  label: Text(l.share),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.done),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
