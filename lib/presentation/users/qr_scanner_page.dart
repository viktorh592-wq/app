/// QR scanner page (V2 USER_DISCOVERY.md §2 — discovery by QR code scan).
/// Returns the raw decoded string to the caller (a pokatuha:// link is
/// dispatched by DeepLinkDispatcher; anything else shows an error).
///
/// Bug 2 (V3.0.3): the page previously relied on `MobileScanner` auto-starting
/// its internal controller. Two regressions were reported:
///   1. Scanning the QR in one direction worked, but in the reverse
///      direction "nothing happens" — the user has no feedback that
///      scanning is actually running.
///   2. There was no explicit "Scan" button, so the user couldn't tell
///      whether the scanner was idle, requesting camera permission, or
///      actively scanning.
///
/// Fix: use an explicit `MobileScannerController`, surface the camera
/// permission state, and add a "Scan" button that toggles scanning.
/// The page also shows a small status banner ("Scanning…" / "Stopped" /
/// "Camera permission denied") so the user is never left guessing.
library;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/domain/services/identity_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _detected = false;

  /// True while we're requesting camera permission so we can show a spinner
  /// instead of a black screen.
  bool _permissionPending = true;

  /// True when the camera permission has been explicitly denied. We render a
  /// "grant permission" CTA in that case.
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
      autoStart: false,
    );
    // Request permission and start scanning after the first frame so the
    // MobileScanner view has a texture to attach to.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop the camera before disposing the controller to avoid a "Tried to
    // send a message on a disposed object" exception (mobile_scanner 5.x).
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume scanning when the app returns to the foreground — Android
    // releases the camera when the app is paused, so we need to restart it
    // explicitly. Without this, returning to the scanner page after the
    // permission dialog leaves the camera stuck (root cause of the
    // "nothing happens" reverse-direction bug).
    if (state == AppLifecycleState.resumed) {
      _start();
    } else if (state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  Future<void> _start() async {
    setState(() {
      _permissionPending = true;
      _permissionDenied = false;
    });
    try {
      await _controller.start();
      if (mounted) {
        setState(() => _permissionPending = false);
      }
    } on MobileScannerException catch (e) {
      if (mounted) {
        setState(() {
          _permissionPending = false;
          _permissionDenied =
              e.errorCode == MobileScannerErrorCode.permissionDenied;
        });
      }
    } catch (_) {
      // Generic camera failure — surface as "permission denied" so the user
      // gets a recoverable CTA instead of a black screen.
      if (mounted) {
        setState(() {
          _permissionPending = false;
          _permissionDenied = true;
        });
      }
    }
  }

  Future<void> _toggleScanning() async {
    if (_permissionPending) return;
    if (_permissionDenied) {
      await _start();
      return;
    }
    try {
      if (_controller.value.isRunning) {
        await _controller.stop();
      } else {
        // Reset the detected flag so a re-scan can pick up the same code
        // again (e.g. if the first detection was rejected by parse()).
        _detected = false;
        await _controller.start();
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Ignore — the user can retry.
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;
      _detected = true;
      // Only pokatuha:// links are meaningful for user/group discovery.
      final link = serviceLocator<IdentityService>().parse(value);
      if (link == null) {
        // Unknown payload — let the user scan again.
        _detected = false;
        if (mounted) {
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.scanFailed)),
          );
        }
        return;
      }
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isRunning = !_permissionPending &&
        !_permissionDenied &&
        (_controller.value.isRunning);

    return Scaffold(
      appBar: AppBar(title: Text(l.scanQr)),
      body: Stack(
        children: [
          // Camera preview. When permission is denied, we still need to
          // mount the MobileScanner so the controller has a surface —
          // but we render the CTA on top of it.
          Positioned.fill(
            child: _permissionDenied
                ? Container(color: Colors.black)
                : MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                  ),
          ),
          // Scan frame hint.
          Center(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isRunning
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          // Top status banner — makes the scanner state explicit so the
          // user is never left wondering whether scanning is running.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(DesignTokens.space3),
                padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space3, vertical: DesignTokens.space2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_permissionPending || isRunning)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.pause_circle_outline_rounded,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _permissionPending
                            ? l.scanning
                            : (_permissionDenied
                                ? l.cameraPermissionDenied
                                : (isRunning ? l.scanning : l.stopScan)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Permission denied CTA.
          if (_permissionDenied)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.space6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.no_photography_rounded,
                        size: 64, color: theme.colorScheme.outline),
                    const SizedBox(height: DesignTokens.space3),
                    Text(
                      l.cameraPermissionDenied,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: DesignTokens.space4),
                    FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l.startScan),
                    ),
                  ],
                ),
              ),
            ),
          // Bottom Scan / Stop button — gives the user an explicit way to
          // (re)start scanning after a failed detection or after pausing.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(DesignTokens.space4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.surface.withValues(alpha: 0),
                      theme.colorScheme.surface.withValues(alpha: 0.9),
                    ],
                  ),
                ),
                child: FilledButton.icon(
                  onPressed: _permissionPending ? null : _toggleScanning,
                  icon: Icon(
                      isRunning ? Icons.stop_rounded : Icons.qr_code_scanner_rounded),
                  label: Text(isRunning ? l.stopScan : l.startScan),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
