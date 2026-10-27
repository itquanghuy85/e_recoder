import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Runtime permissions the app asks for, behind an interface so screens and tests never touch
/// the plugin directly. (Overlay permission is special and lives in [NativeRecorder].)
abstract class PermissionsGateway {
  Future<bool> micGranted();
  Future<bool> requestMic();
  Future<bool> notificationsGranted();
  Future<bool> requestNotifications();
  Future<void> openSettings();
}

class PermissionHandlerGateway implements PermissionsGateway {
  @override
  Future<bool> micGranted() async {
    try {
      return (await Permission.microphone.status).isGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestMic() async {
    try {
      return (await Permission.microphone.request()).isGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> notificationsGranted() async {
    try {
      return (await Permission.notification.status).isGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestNotifications() async {
    try {
      return (await Permission.notification.request()).isGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}

final permissionsGatewayProvider = Provider<PermissionsGateway>(
  (ref) => PermissionHandlerGateway(),
);
