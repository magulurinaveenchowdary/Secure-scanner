import 'dart:async';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';

class CallManager {
  static final CallManager _instance = CallManager._();

  factory CallManager() => _instance;

  CallManager._();

  // ignore: unused_field
  StreamSubscription<PhoneState>? _subscription;
  // ignore: unused_field
  PhoneStateStatus _lastStatus = PhoneStateStatus.NOTHING;

  Future<void> init() async {
    try {
      await _requestPermissions();
      _subscription = PhoneState.stream.listen((event) {
        _handlePhoneState(event.status);
      });
    } catch (e) {
      print("Error initializing CallManager: $e");
      // Continue app even if overlay setup fails
    }
  }

  Future<void> _requestPermissions() async {
    await [Permission.phone, Permission.systemAlertWindow].request();
  }

  void _handlePhoneState(PhoneStateStatus status) async {
    try {
      print("Phone State Changed: $status");

      // Only handle initial launch on Incoming Call
      if (status == PhoneStateStatus.CALL_INCOMING) {
        final bool isActive = await FlutterOverlayWindow.isActive();
        if (isActive) {
          await FlutterOverlayWindow.shareData("incoming");
        } else {
          await _showOverlay("Incoming Call...", isFull: true);
          await Future.delayed(Duration(milliseconds: 500));
          await FlutterOverlayWindow.shareData("incoming");
        }
      }
      // Outgoing Call (Started but not active yet)
      else if (status == PhoneStateStatus.CALL_STARTED) {
        final bool isActive = await FlutterOverlayWindow.isActive();
        if (!isActive) {
          // Outgoing call -> Show minimized overlay immediately
          await _showOverlay("In Call", isFull: false);
          await Future.delayed(Duration(milliseconds: 500));
          await FlutterOverlayWindow.shareData("outgoing");
        }
        // If already active (was incoming), the OverlayWidget's PhoneState listener will handle resizing
      }
      // All other state changes (Started, Ended) are handled by the Overlay itself
      // to ensure it survives even if the main app is killed.

      _lastStatus = status;
    } catch (e) {
      print("Error in _handlePhoneState: $e");
      // Don't let exceptions crash the app
    }
  }

  Future<void> _showOverlay(String message, {bool isFull = true}) async {
    try {
      final bool isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        return;
      }

      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "SecureScan Call Alert",
        overlayContent: "Call Alert",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: isFull
            ? WindowSize.matchParent
            : 40, // Small bubble for outgoing
        width: isFull ? WindowSize.matchParent : 40,
      );
    } catch (e) {
      print("Error showing overlay: $e");
      // Continue without showing overlay if it fails
    }
    // We can't easily pass dynamic arguments to showOverlay in the current plugin version
    // unless we use shareData BEFORE or AFTER logic.
    // The widget can default to "Incoming" or we can use shareData to tell it.

    if (message == "Call Ended") {
      await Future.delayed(Duration(milliseconds: 500));
      await FlutterOverlayWindow.shareData("ended");
    }
  }
}
