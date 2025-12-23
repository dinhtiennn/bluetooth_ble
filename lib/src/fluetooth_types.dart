part of 'package:bluetooth_ble/bluetooth_ble.dart';

class FluetoothConst {
  static const Duration defDiscoveryTimeout = Duration(seconds: 10);
}

enum BluetoothProtocol { ble, classic }

class FluetoothDevice<T> {
  T origin;
  BluetoothProtocol protocol;
  String? name;
  String? mac;
  int? rssi;

  FluetoothDevice({
    required this.origin,
    required this.protocol,
    this.name,
    this.mac,
    this.rssi,
  });
}


