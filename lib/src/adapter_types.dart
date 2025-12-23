part of 'package:bluetooth_ble/bluetooth_ble.dart';

enum ConnectionState {
  connected,
  disconnected,
}

class ReadOptions {
  int timeout;
  ReadOptions({this.timeout = 10});
}

abstract class ConnectedDevice<T> {
  T? origin();
  String? deviceName();
  String? deviceMac();
  ConnectionState connectionState();
  Future<void> disconnect();
  Future<void> write(Uint8List data, {bool sendDone = true});
  Stream<Uint8List> read(ReadOptions? options);
}


