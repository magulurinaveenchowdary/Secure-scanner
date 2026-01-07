// created_qr_modal_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../themes.dart';

/// Full-screen modal / screen for a created QR code.
/// - SAVE: saves QR image to app documents directory (no gallery/plugin permissions)
/// - SHARE: shares the QR image file
/// - CLOSE: closes the screen
///
/// Special display handling:
/// - Contact (vCard / MECARD): shows only Name and Phone in display area
/// - Wi-Fi: shows SSID (if parseable)
/// - URL: shows URL
class CreatedQrModalScreen extends StatefulWidget {
  final String type; // e.g. "Contact", "Wi-Fi", "URL", "Content"
  final String value; // the full payload used to generate QR
  final String time;

  const CreatedQrModalScreen({
    super.key,
    required this.type,
    required this.value,
    required this.time,
  });

  @override
  State<CreatedQrModalScreen> createState() => _CreatedQrModalScreenState();
}

class _CreatedQrModalScreenState extends State<CreatedQrModalScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _working = false;

  // Capture the RepaintBoundary as PNG bytes
  Future<Uint8List?> _capturePngBytes() async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      if (kDebugMode) print('capture error: $e');
      return null;
    }
  }

  /// Conventional save: write PNG bytes to the app documents directory and show path.
  Future<void> _saveToDocuments() async {
    setState(() => _working = true);

    final bytes = await _capturePngBytes();
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture image')),
        );
      }
      setState(() => _working = false);
      return;
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final filename = 'qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${docDir.path}/$filename');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
      }
    } catch (e) {
      if (kDebugMode) print('save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving image: $e')));
      }
    } finally {
      setState(() => _working = false);
    }
  }

  Future<void> _shareImage() async {
    setState(() => _working = true);

    final bytes = await _capturePngBytes();
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture image')),
        );
      }
      setState(() => _working = false);
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/qr_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)], text: '${widget.type} QR');
    } catch (e) {
      if (kDebugMode) print('share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing image: $e')));
      }
    } finally {
      setState(() => _working = false);
    }
  }

  // ---------- Display helpers for different types ----------

  // Parse MECARD or vCard-ish content for simple display: name and phone
  Map<String, String> _parseContact(String payload) {
    final out = <String, String>{'name': '', 'tel': ''};
    final p = payload.trim();

    try {
      final up = p.toUpperCase();
      if (up.startsWith('MECARD:')) {
        final body = p.substring(7);
        final parts = body.split(';');
        for (final seg in parts) {
          if (seg.startsWith('N:')) {
            out['name'] = seg.substring(2).replaceAll('\\,', ',');
          } else if (seg.startsWith('TEL:')) {
            out['tel'] = seg.substring(4);
          }
        }
      } else if (up.contains('BEGIN:VCARD')) {
        // naive vCard parse
        final lines = p.split(RegExp(r'\r?\n'));
        for (final l in lines) {
          final line = l.trim();
          if (line.toUpperCase().startsWith('FN:') ||
              line.toUpperCase().startsWith('N:')) {
            final idx = line.indexOf(':');
            if (idx >= 0) out['name'] = line.substring(idx + 1);
          } else if (line.toUpperCase().startsWith('TEL')) {
            final idx = line.indexOf(':');
            if (idx >= 0) out['tel'] = line.substring(idx + 1);
          }
        }
      } else {
        // Fallback: try to find TEL= or TEL: or TEL;
        final telMatch = RegExp(
          r'(TEL[:=]\s*([+\d\-\s\(\)]+))',
          caseSensitive: false,
        ).firstMatch(p);
        if (telMatch != null) out['tel'] = telMatch.group(2) ?? '';
        // Try to extract a name after N: or NAME=
        final nmMatch = RegExp(
          r'(N:|NAME=)([^;,\n]+)',
          caseSensitive: false,
        ).firstMatch(p);
        if (nmMatch != null) out['name'] = nmMatch.group(2) ?? '';
      }
    } catch (_) {
      // ignore parse errors
    }

    out['name'] = (out['name'] ?? '').trim();
    out['tel'] = (out['tel'] ?? '').trim();
    return out;
  }

  // Parse WiFi: payloads typically like: WIFI:S:MySSID;T:WPA;P:mypass;;
  String? _parseWifiSsid(String payload) {
    if (!payload.startsWith('WIFI:')) return null;
    final rest = payload.substring(5);
    final parts = rest.split(';');
    for (final p in parts) {
      if (p.startsWith('S:')) return p.substring(2);
    }
    return null;
  }

  String _displayShort() {
    final t = widget.type.toLowerCase();
    final val = widget.value;
    if (t == 'contact' || t == 'vcard' || t == 'mecard') {
      final c = _parseContact(val);
      final name = c['name']?.isNotEmpty == true ? c['name']! : 'Contact';
      final tel = c['tel']?.isNotEmpty == true ? c['tel']! : '';
      if (tel.isNotEmpty) return '$name • $tel';
      return name;
    } else if (t == 'wi-fi' || t == 'wifi') {
      final ssid = _parseWifiSsid(val);
      return ssid ?? val;
    } else if (t == 'url') {
      return val;
    } else {
      // fallback: show at most 120 chars
      return val.length <= 120 ? val : '${val.substring(0, 120)}...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final displayShort = _displayShort();

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 1,
        centerTitle: true,
        title: Text(
          widget.type,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // QR container (captured for saving/sharing)
                    RepaintBoundary(
                      key: _repaintKey,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 50),
                        padding: const EdgeInsets.symmetric(
                          vertical: 30,
                          horizontal: 40,
                        ),
                        decoration: BoxDecoration(
                          color: SecureScanTheme.accentBlue,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'YOUR QR CODE',
                              style: textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: 260,
                              height: 260,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: QrImageView(
                                data: widget.value,
                                version: QrVersions.auto,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 18),
                            // simplified display text (name + phone for contact, ssid for wifi, url for url)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                              ),
                              child: Text(
                                displayShort,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.time,
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Buttons row (icons + labels)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: _working
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.save,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                              label: const Text(
                                'SAVE',
                                style: TextStyle(color: Colors.white),
                              ),
                              onPressed: _working ? null : _saveToDocuments,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SecureScanTheme.accentBlue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.share,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'SHARE',
                                style: TextStyle(color: Colors.white),
                              ),
                              onPressed: _working ? null : _shareImage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SecureScanTheme.accentBlue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Banner-style ad slot at bottom: grey background, white text
            Container(
              width: double.infinity,
              height: 70,
              color: Colors.grey.shade800, // darker grey for banner look
              alignment: Alignment.center,
              child: Text(
                'AD BANNER',
                style: textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
