part of 'package:bluetooth_ble/bluetooth_ble.dart';

class BLEBluetoothDevice extends FluetoothDevice<BleDevice> {
  BLEBluetoothDevice({
    required BleDevice origin,
    String? name,
    String? mac,
    int? rssi,
  }) : super(
          origin: origin,
          protocol: BluetoothProtocol.ble,
          name: name ?? origin.name,
          mac: mac ?? origin.deviceId,
          rssi: rssi,
        );
}
