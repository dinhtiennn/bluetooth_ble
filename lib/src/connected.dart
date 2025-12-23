import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:psdk_bluetooth_ble/psdk_bluetooth_ble.dart';

/// BLE connected device
class BLEConnectedDevice extends ConnectedDevice {
  BLEBluetoothDevice? _connectedDevice;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  final _readController = StreamController<Uint8List>.broadcast();
  bool _isWriting = false;
  ConnectionState _state = ConnectionState.disconnected;

  BLEConnectedDevice({
    required BluetoothDevice device,
    required BLEBluetoothDevice connectedDevice,
    BluetoothCharacteristic? writeCharacteristic,
    BluetoothCharacteristic? notifyCharacteristic,
  }) {
    _device = device;
    _connectedDevice = connectedDevice;
    _writeCharacteristic = writeCharacteristic;
    _notifyCharacteristic = notifyCharacteristic;

    _state = ConnectionState.connected;
    _connectionSubscription = _device!.connectionState.listen((s) {
      _state =
          s == BluetoothConnectionState.connected ? ConnectionState.connected : ConnectionState.disconnected;
    });

    final c = _notifyCharacteristic;
    if (c != null) {
      // fire and forget; if device doesn't support notify this may throw later on connect path
      c.setNotifyValue(true);
      _notifySubscription = c.onValueReceived.listen((data) {
        _readController.add(Uint8List.fromList(data));
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
      await _device?.disconnect();
    } catch (_) {
      // ignore
    }
    _connectedDevice = null;
    _device = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
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
    if (_device == null) {
      throw Exception(
        '[bluetooth-ble] failed to get connectedDevice origin, may not connect printer?',
      );
    }
    final characteristic = _writeCharacteristic ?? _notifyCharacteristic;
    if (characteristic == null) {
      throw Exception('[bluetooth-ble] no writable characteristic selected');
    }
    // 加锁
    if (_isWriting) {
      throw Exception("[bluetooth-ble] write is already in progress");
    }
    _isWriting = true;
    try {
      final withoutResponse = characteristic.properties.writeWithoutResponse;
      await characteristic.write(
        data,
        withoutResponse: withoutResponse,
        allowLongWrite: true,
      );
    } finally {
      // 释放锁
      _isWriting = false;
    }
  }
}
