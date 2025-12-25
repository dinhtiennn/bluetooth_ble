/// The ble bluetooth package
///
library bluetooth_ble;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import 'src/types.dart';

part 'src/adapter_types.dart';
part 'src/traits.dart';
part 'src/fluetooth_types.dart';

part 'src/connected.dart';
part 'src/device.dart';
part 'src/provider.dart';

/// Lightweight debug logger for this package.
///
/// - Default: enabled in debug builds only.
/// - You can override at runtime: `BluetoothBleLog.enabled = true/false`.
class BluetoothBleLog {
  static bool enabled = kDebugMode;

  static void d(String message) {
    if (!enabled) return;
    debugPrint('[bluetooth-ble] $message');
  }

  static String hexPreview(List<int> bytes, {int max = 16}) {
    if (bytes.isEmpty) return '';
    final n = bytes.length < max ? bytes.length : max;
    final b = bytes.take(n).map((v) => v.toRadixString(16).padLeft(2, '0'));
    final suffix = bytes.length > n ? '…' : '';
    return '${b.join(' ')}$suffix';
  }
}
