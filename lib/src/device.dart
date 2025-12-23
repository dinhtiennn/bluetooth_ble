part of 'package:bluetooth_ble/bluetooth_ble.dart';

class BLEBluetoothDevice extends FluetoothDevice<BluetoothDevice> {
  BLEBluetoothDevice({
    required BluetoothDevice origin,
    String? name,
    String? mac,
    int? rssi,
  }) : super(
          origin: origin,
          protocol: BluetoothProtocol.ble,
          name: name,
          mac: mac,
          rssi: rssi,
        );
}
