import 'package:e_screen_recorder/core/native_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('what can this phone recognise on the device', (t) async {
    final r = await NativeRecorder().sttSupport(['vi-VN', 'en-US', 'en-GB']);
    // ignore: avoid_print
    print('STT available=${r.available} languages=${r.languages}');
  });
}
