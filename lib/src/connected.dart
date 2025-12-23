part of 'package:bluetooth_ble/bluetooth_ble.dart';

/// BLE connected device
class BLEConnectedDevice extends ConnectedDevice<BLEBluetoothDevice> {
  BLEBluetoothDevice? _connectedDevice;
  final String _deviceId;
  final BleQualifiedCharacteristic? _write;
  final BleQualifiedCharacteristic? _notify;
  StreamSubscription<Uint8List>? _notifySubscription;
  StreamSubscription<bool>? _connectionSubscription;
  final _readController = StreamController<Uint8List>.broadcast();
  bool _isWriting = false;
  ConnectionState _state = ConnectionState.disconnected;

  BLEConnectedDevice({
    required String deviceId,
    required BLEBluetoothDevice connectedDevice,
    required BleQualifiedCharacteristic? write,
    required BleQualifiedCharacteristic? notify,
  })  : _deviceId = deviceId,
        _write = write,
        _notify = notify {
    _connectedDevice = connectedDevice;

    _state = ConnectionState.connected;

    _connectionSubscription = UniversalBle.connectionStream(_deviceId).listen((isConnected) {
      _state = isConnected ? ConnectionState.connected : ConnectionState.disconnected;
    });

    final n = _notify;
    if (n != null) {
      // subscribe to notifications/indications if supported
      if (n.characteristic.properties.contains(CharacteristicProperty.notify)) {
        UniversalBle.subscribeNotifications(
          _deviceId,
          n.serviceUuid,
          n.characteristic.uuid,
        );
      } else if (n.characteristic.properties
          .contains(CharacteristicProperty.indicate)) {
        UniversalBle.subscribeIndications(
          _deviceId,
          n.serviceUuid,
          n.characteristic.uuid,
        );
      }
      _notifySubscription = UniversalBle.characteristicValueStream(
        _deviceId,
        n.characteristic.uuid,
      ).listen((data) {
        _readController.add(data);
      });
    }
  }

  @override
  BLEBluetoothDevice? origin() {
    return _connectedDevice;
  }

  @override
  ConnectionState connectionState() {
    return _state;
  }

  @override
  String? deviceName() {
    return _connectedDevice?.name;
  }

  @override
  String? deviceMac() {
    return _connectedDevice?.mac;
  }

  @override
  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    try {
      final n = _notify;
      if (n != null) {
        await UniversalBle.unsubscribe(_deviceId, n.serviceUuid, n.characteristic.uuid);
      }
      await UniversalBle.disconnect(_deviceId);
    } catch (_) {
      // ignore
    }
    _connectedDevice = null;
    _state = ConnectionState.disconnected;
  }

  @override
  Stream<Uint8List> read(ReadOptions? options) {
    return _readController.stream;
  }

  @override
  Future<void> write(
    Uint8List data, {
    bool sendDone = true,
  }) async {
    if (ConnectionState.disconnected == connectionState()) {
      throw Exception("[bluetooth-ble] the printer isn't connect");
    }
    final target = _write ?? _notify;
    if (target == null) {
      throw Exception('[bluetooth-ble] no writable characteristic selected');
    }
    // 加锁
    if (_isWriting) {
      throw Exception("[bluetooth-ble] write is already in progress");
    }
    _isWriting = true;
    try {
      final withoutResponse = target.characteristic.properties
          .contains(CharacteristicProperty.writeWithoutResponse);
      await UniversalBle.write(
        _deviceId,
        target.serviceUuid,
        target.characteristic.uuid,
        data,
        withoutResponse: withoutResponse,
      );
    } finally {
      // 释放锁
      _isWriting = false;
    }
  }
}
