part of 'package:bluetooth_ble/bluetooth_ble.dart';

abstract class Fluetooth<PROVIDER, DEVICE extends FluetoothDevice> {
  PROVIDER origin();
  Future<bool> availableBluetooth();
  Future<bool> bluetoothIsEnabled();
  Future<bool> isConnected();
  Future<bool> isDiscovery();

  // Compatibility with older psdk_bluetooth_traits (polling streams were removed)
  Future<void> init() async {}

  Future<void> startDiscovery({
    bool disconnectConnectedDevice = true,
    Duration timeout = FluetoothConst.defDiscoveryTimeout,
  });
  Future<void> stopDiscovery();
  Stream<DEVICE> discovered();
  Future<ConnectedDevice> connect(DEVICE device);
}


