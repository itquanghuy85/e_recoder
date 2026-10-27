import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected bottom-navigation tab (0 Quay, 1 Thư viện, 2 Cài đặt).
class ShellIndex extends Notifier<int> {
  @override
  int build() => 0;
  void go(int i) => state = i;
}

final shellIndexProvider = NotifierProvider<ShellIndex, int>(ShellIndex.new);
