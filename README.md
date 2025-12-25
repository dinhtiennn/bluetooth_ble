bluetooth_ble
===

BLE wrapper for Flutter built on top of `universal_ble`.

### iOS support

This package **can be used on iOS**, because all BLE operations are provided by the dependency `universal_ble` (CoreBluetooth on iOS).

Important notes for iOS:
- **Test on a real iPhone/iPad** (BLE scanning does not work on the iOS simulator).
- Add Bluetooth permission descriptions to your app `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to the printer.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to connect to the printer.</string>
```

If your device is not discoverable on iOS, ensure it advertises properly and exposes a writable GATT characteristic (write / writeWithoutResponse).
