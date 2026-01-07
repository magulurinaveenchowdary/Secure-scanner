// lib/widgets/app_drawer.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:securescan/widgets/bottom_nav_shell.dart';
import 'package:share_plus/share_plus.dart';

// Mobile scanner package (screens that perform scanning should use this)
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

import 'package:securescan/features/scan/screens/scan_screen_qr.dart'; // provides QrResultData
import 'package:securescan/features/scan/screens/scan_screen_qr.dart'
    as scan_qr;
import 'package:securescan/features/scan/screens/scan_screen_qr.dart'
    as qr_screen_import;

import 'package:securescan/features/generate/screens/generator_screen.dart';
import 'package:securescan/features/generate/screens/my_qr_screen.dart';

import '../features/scan/screens/qr_result_screen.dart';
import 'package:securescan/themes.dart'; // <-- needed for SecureScanThemeController

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    this.currentBottomIndex = 0,
    this.onSelectBottomNavIndex,
  });
  static const String routeName = "ScanScreenQR";

  /// Which bottom-nav tab is currently active (0 = Home, 1 = History, 2 = Settings)
  final int currentBottomIndex;

  /// If provided, we’ll use this to switch tabs instead of pushing new routes
  final ValueChanged<int>? onSelectBottomNavIndex;

  static const _primaryBlue = Color(0xFF0A66FF);

  // TODO: Replace with your real Play Store URL
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.securescan.securescan';

  static const String _shareMessage =
      'I am using QR & Barcode Scanner Generator App, the fast and secure QR and Barcode reader. '
      'Try it now! $_playStoreUrl';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width * 0.66;

    return Drawer(
      width: width,
      elevation: 12,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Image.asset(
                        'assets/secure_scan_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: const Color(0xFFE0E0E0)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'QR & Barcode Scanner Generator',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _divider(),

            // ---- Home (BottomNav index: 0) ----
            _DrawerTile(
              title: 'Home',
              iconPath: 'assets/icons/bottom_nav_icons/home_inactive.png',
              iconTint: currentBottomIndex == 0
                  ? _primaryBlue
                  : Colors.grey[700],
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => BottomNavShell()),
                );
              },
            ),
            _divider(),

            // Scan QR (camera)
            _DrawerTile(
              title: 'Scan QR',
              iconPath: 'assets/icons/misc/scan_qr_icon_white.png',
              iconTint: _primaryBlue,
              onTap: () {
                Navigator.of(context).pop(); // close drawer

                // 🔥 If already on ScanScreenQR, do nothing
                if (ModalRoute.of(context)?.settings.name == "ScanScreenQR") {
                  return;
                }

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: "ScanScreenQR"),
                    builder: (_) => ScanScreenQR(),
                  ),
                );
              },
            ),

            _divider(),

            // Scan Image (from gallery) — perform inline pick + analyze and navigate to QrResultScreen when detected
            _DrawerTile(
              title: 'Scan Image',
              iconPath: 'assets/icons/misc/scan_image_icon.png',
              iconTint: _primaryBlue,
              // Replace the existing Scan Image onTap handler with this:
              onTap: () async {
                // Close drawer first so gallery isn't obstructed
                Navigator.of(context).pop();

                // Capture the root navigator (we'll use its context for dialogs/navigation)
                final NavigatorState rootNav = Navigator.of(
                  context,
                  rootNavigator: true,
                );

                // Small delay to allow drawer close animation to finish before showing dialogs
                await Future.delayed(const Duration(milliseconds: 250));

                final messenger = ScaffoldMessenger.of(rootNav.context);
                final picker = ImagePicker();

                XFile? image;
                try {
                  image = await picker.pickImage(source: ImageSource.gallery);
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Could not open gallery: $e')),
                  );
                  return;
                }

                if (image == null) {
                  // user cancelled picker
                  return;
                }

                // Show loading dialog on root navigator
                rootNav
                    .context; // just to be explicit about where we show dialog
                showDialog(
                  context: rootNav.context,
                  barrierDismissible: false,
                  builder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                );

                final MobileScannerController controller =
                    MobileScannerController();
                try {
                  final capture = await controller.analyzeImage(image.path);

                  // read image bytes for result screen
                  Uint8List? imageBytes;
                  try {
                    imageBytes = await File(image.path).readAsBytes();
                  } catch (_) {
                    imageBytes = null;
                  }

                  // Dismiss loading dialog (use root navigator)
                  try {
                    if (Navigator.of(rootNav.context).canPop()) {
                      Navigator.of(rootNav.context).pop();
                    }
                  } catch (_) {}

                  if (capture != null && capture.barcodes.isNotEmpty) {
                    final first = capture.barcodes.first;
                    final value = first.rawValue ?? '';

                    if (value.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'QR / Barcode detected, but has no data.',
                          ),
                        ),
                      );
                      return;
                    }

                    // Construct QrResultData (adjust field names if your model differs)
                    final qrResult = QrResultData(
                      raw: value,
                      kind: _inferKind(value),
                      format: first.format?.toString(),
                      timestamp: DateTime.now(),
                      data: null,
                      imageBytes: imageBytes,
                    );

                    // Navigate to result screen using root navigator context
                    Navigator.of(rootNav.context).push(
                      MaterialPageRoute(
                        builder: (_) => QrResultScreen(result: qrResult),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('No QR / Barcode found in this image.'),
                      ),
                    );
                  }
                } catch (e) {
                  // Ensure loading was dismissed
                  try {
                    if (Navigator.of(rootNav.context).canPop()) {
                      Navigator.of(rootNav.context).pop();
                    }
                  } catch (_) {}

                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to scan image: $e')),
                  );
                } finally {
                  controller.dispose();
                }
              },
            ),
            _divider(),

            // Create QR
            _DrawerTile(
              title: 'Create QR',
              iconPath: 'assets/icons/misc/create_qr_icon_white.png',
              iconTint: _primaryBlue,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CreateQRScreen()),
                );
              },
            ),
            _divider(),

            // My QR (saved contact QR)
            _DrawerTile(
              title: 'My QR',
              iconPath: 'assets/icons/misc/my_qr_icon.png',
              iconTint: _primaryBlue,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyQrScreen()),
                );
              },
            ),
            _divider(),

            // History (BottomNav index: 1)
            _DrawerTile(
              title: 'History',
              iconPath: 'assets/icons/misc/history_App Drawer_icon.png',
              iconTint: _primaryBlue,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BottomNavShell(initialIndex: 1),
                  ),
                );
              },
            ),
            _divider(),

            // Settings (BottomNav index: 2)
            _DrawerTile(
              title: 'Settings',
              iconPath: 'assets/icons/bottom_nav_icons/settings_inactive.png',
              iconTint: _primaryBlue,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BottomNavShell(initialIndex: 2),
                  ),
                );
              },
            ),
            _divider(),

            // Share App
            _DrawerTile(
              title: 'Share App',
              iconPath: 'assets/icons/misc/share_icon.png',
              iconTint: _primaryBlue,
              onTap: () async {
                Navigator.of(context).pop();
                await Share.share(_shareMessage);
              },
            ),
            _divider(),

            // Change Theme (toggle light/dark)
            _DrawerTile(
              title: 'Change Theme',
              iconPath: 'assets/icons/misc/theme_icon.png',
              iconTint: _primaryBlue,
              onTap: () async {
                Navigator.of(context).pop();

                final currentMode =
                    SecureScanThemeController.instance.themeModeNotifier.value;

                // Determine the new mode:
                ThemeMode newMode;
                if (currentMode == ThemeMode.system) {
                  // If system, infer platform brightness and toggle to opposite
                  final platformBrightness = MediaQuery.platformBrightnessOf(
                    context,
                  );
                  newMode = platformBrightness == Brightness.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                } else {
                  newMode = currentMode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                }

                // Persist and apply new theme
                await SecureScanThemeController.instance.setTheme(
                  SecureScanThemeController.themeModeToString(newMode),
                );

                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Theme set to ${SecureScanThemeController.themeModeToString(newMode)}',
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: _primaryBlue,
                  ),
                );
              },
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  static Widget _divider() => Divider(
    height: 1,
    thickness: 1,
    color: const Color(0xFF000000).withOpacity(0.1),
  );

  /// Quick lightweight inference for basic kinds. Replace with your real parser if available.
  static String _inferKind(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://'))
      return 'url';
    if (lower.startsWith('mailto:')) return 'email';
    if (lower.startsWith('tel:') || RegExp(r'^\+?\d+$').hasMatch(lower))
      return 'phone';
    if (lower.startsWith('wifi:') || lower.startsWith('WIFI:'.toLowerCase()))
      return 'wifi';
    if (lower.contains('begin:vcard')) return 'vcard';
    if (lower.contains('begin:VEVENT'.toLowerCase()) ||
        lower.contains('calendar'))
      return 'calendar';
    if (lower.startsWith('geo:')) return 'geo';
    // fallback
    return 'text';
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.title,
    required this.iconPath,
    required this.onTap,
    this.iconTint,
  });

  final String title;
  final String iconPath;
  final VoidCallback onTap;
  final Color? iconTint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Image.asset(iconPath, width: 20, height: 20, color: iconTint),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
      horizontalTitleGap: 16,
      minLeadingWidth: 28,
    );
  }
}
