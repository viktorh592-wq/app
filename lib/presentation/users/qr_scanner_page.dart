/// QR scanner page (V2 USER_DISCOVERY.md §2 — discovery by QR code scan).
///
/// V3.0.4 (bug 2) — «пользователь 2 сканирует QR и ничего не происходит»:
/// the old page relied on `MobileScanner` auto-starting its internal
/// controller and gave the user zero feedback. This version:
///   * owns an explicit [MobileScannerController] (autoStart: false);
///   * shows a big «Сканировать» / «Пауза» button so the user always knows
///     whether scanning is running;
///   * surfaces the state in a status chip (starting / active / paused /
///     camera permission denied) instead of a silent black preview;
///   * restarts the camera when the app returns to the foreground (the OS
///     releases it while backgrounded — a known cause of the frozen
///     preview that looks like "nothing happens");
///   * on an unrecognized code keeps scanning and shows a snackbar instead
///     of closing the page.
///
/// Returns the raw decoded string to the caller (a `pokatuha://` link is
/// dispatched by DeepLinkDispatcher; anything else shows an error).
library;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:pokatuha/domain/services/identity_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';

enum _ScannerState { starting, active, paused, permissionDenied }

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  _ScannerState _state = _ScannerState.starting;
  bool _detected = false;

  bool get _scanning =>
      _state == _ScannerState.active || _state == _ScannerState.starting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
      autoStart: false,
    );
    // Start after the first frame so the texture exists on the view side.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScanning());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.stop().catchError((_) {});
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android releases the camera when the app is paused. Without an
    // explicit restart the preview stays frozen after returning — the
    // user perceives it as «сканирование не работает».
    if (state == AppLifecycleState.resumed && _scanning) {
      _startScanning();
    }
  }

  Future<void> _startScanning() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    setState(() => _state = _ScannerState.starting);
    try {
      await controller.start();
      if (mounted) setState(() => _state = _ScannerState.active);
    } catch (_) {
      // Typically CameraException with permissionDenied — offer the
      // settings CTA instead of a black screen.
      if (mounted) setState(() => _state = _ScannerState.permissionDenied);
    }
  }

  Future<void> _pauseScanning() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    try {
      await controller.stop();
    } catch (_) {}
    if (mounted) setState(() => _state = _ScannerState.paused);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected || _state != _ScannerState.active) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;
      final link = serviceLocator<IdentityService>().parse(value);
      if (link == null) {
        // Unknown payload — tell the user and keep scanning (the old page
        // closed silently, which felt like «ничего не происходит»).
        _detected = true;
        if (mounted) {
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.invalidQr)));
        }
        Future<void>.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _detected = false);
        });
        return;
      }
      _detected = true;
      // A small delay so the user sees the frame react before the page
      // closes (prevents the «моргнуло и ничего» effect).
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        Navigator.of(context).pop(value);
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final controller = _controller;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.scanQr)),
      body: Stack(
        children: [
          // Camera preview (or a placeholder while starting / denied).
          if (controller != null &&
              _state != _ScannerState.permissionDenied)
            MobileScanner(
              controller: controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) =>
                  _PermissionPlaceholder(
                message: l.cameraPermissionDenied,
              ),
            )
          else
            _PermissionPlaceholder(message: l.cameraPermissionDenied),
          // Scan frame hint.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Status chip — the user always knows whether scanning runs.
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(child: _statusChip(l, theme)),
          ),
          // Bottom control bar with the explicit scan toggle.
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                ),
                onPressed: () => _scanning ? _pauseScanning() : _startScanning(),
                icon: Icon(_scanning
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_arrow_rounded),
                label: Text(
                  _state == _ScannerState.starting
                      ? l.scanStarting
                      : _scanning
                          ? l.scanPause
                          : l.scanStart,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(AppLocalizations l, ThemeData theme) {
    final (icon, text) = switch (_state) {
      _ScannerState.starting => (
          Icons.hourglass_top_rounded,
          l.scanStarting
        ),
      _ScannerState.active => (Icons.radar_rounded, l.scanActive),
      _ScannerState.paused => (Icons.pause_circle_outline_rounded,
          l.scanStopped),
      _ScannerState.permissionDenied => (
          Icons.videocam_off_rounded,
          l.cameraPermissionDenied
        ),
    };
    return Material(
      color: theme.colorScheme.surface.withOpacity(0.85),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18, color: theme.colorScheme.onSurface.withOpacity(0.7)),
            const SizedBox(width: 8),
            Text(text, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Black placeholder with the permission message (used while the camera is
/// unavailable or the permission was denied).
class _PermissionPlaceholder extends StatelessWidget {
  const _PermissionPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.white70),
      ),
    );
  }
}
