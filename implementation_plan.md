# After-Call Feature Implementation Plan

## Objective
Develop a premium "After-Call" screen for SecureScan that appears automatically when a call ends. This screen will facilitate quick contact sharing via QR codes and provide security insights, all within a high-quality, glassmorphic UI overlay.

## 1. Design & Authenticity (Visuals)
We will implement the "Dark Glassmorphism" aesthetic approval in the mockup. This includes:
- **Background**: Deep blue/black radial gradient.
- **Card**: Translucent white/glass container with blur effect (`BackdropFilter`).
- **Typography**: Google Fonts 'Inter' or 'Roboto', clean white text.
- **Animations**: Smooth fade-in on call end.

## 2. Technical Architecture
We will utilize `flutter_overlay_window` for the "on top of all apps" capability and `phone_state` for precise call lifecycle detection.

### A. Permission Management
- Ensure `SYSTEM_ALERT_WINDOW` and `READ_PHONE_STATE` are active.
- `CallManager` will check permissions on startup and prompt if missing.

### B. Call Logic (`CallManager.dart`)
- **Incoming Call**: Show non-intrusive "Incoming" pill or full screen (user preference).
- **Call Started**: Minimize to small floating bubble.
- **Call Ended**:
    - Trigger `CALL_ENDED` event.
    - **Maximize** the overlay to `WindowSize.matchParent`.
    - Update overlay state to `AfterCall` mode.
    - Start a 5-10s timer (optional) or wait for user interaction to close.

### C. UI Component (`CallOverlayWidget.dart`)
We will refactor `CallOverlayWidget` to support the new Full Screen design.

**Structure:**
- **Status Bar**: "Safe Link Verified" badge (Green).
- **Header**: "SecureScan" Logo + "Call Ended".
- **Contact Info**: Display Name/Number of the other party (retrieved from `phone_state`).
- **Main Action**: Large QR Code (generated for the user's contact card).
- **Action Buttons**:
    - "Share" (System Share Sheet).
    - "Scan New Code" (Closes overlay -> Opens App -> Navigates to Scan Screen).
    - "Create Other QR" (Closes overlay -> Opens App -> Navigates to Generator).
- **Ad Space**: Native-looking placeholder for AdMob banner (300x250 or fluid).

## 3. Detailed Steps
1.  **Modify `CallManager`**: Improve `_handlePhoneState` to strictly handle `CALL_ENDED` transition to full screen.
2.  **Update `CallOverlayWidget`**: Replace the current white card design with the Dark/Glass theme.
3.  **Add `Scan` Action**: Implement `FlutterOverlayWindow.closeOverlay()` followed by `ExternalAppLauncher` or deep linking to open the main app's Scan tab.
4.  **Testing**: Verify flow: Incoming -> Answer -> Hangup -> **Overlay Maximizes**.

## 4. User Approval
Please review the generated Mockup (Image) to confirm the visual direction.
