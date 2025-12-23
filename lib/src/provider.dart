part of 'package:psdk_bluetooth_ble/psdk_bluetooth_ble.dart';

/// ble bluetooth provider
class BLEBluetooth
    extends Fluetooth<FlutterBluePlusProvider, BLEBluetoothDevice> {
  final FlutterBluePlusProvider _provider = const FlutterBluePlusProvider();
  final _discoveryController = StreamController<BLEBluetoothDevice>.broadcast();
  BLEConnectedDevice? _connectedDevice;
  final Set<String> _notifiedDeviceIds = <String>{};
  static BLEBluetooth? _bleBluetooth;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  ///唯一值使用mac地址还是uuid
  bool useMac = true;
  List<AllowService>? _allowedServices;
  String? _allowedCharacteristic;
  bool _allowDetectDifferentCharacteristic = true;

  factory BLEBluetooth({
    List<AllowService>? allowedServices,
    String? allowedCharacteristic,
    bool allowDetectDifferentCharacteristic = true,
  }) {
    final instance = _bleBluetooth ??= BLEBluetooth._();
    instance._allowedServices = allowedServices;
    instance._allowedCharacteristic = allowedCharacteristic;
    instance._allowDetectDifferentCharacteristic =
        allowDetectDifferentCharacteristic;
    return instance;
  }

  BLEBluetooth._() {
    super.init();
  }

  @override
  FlutterBluePlusProvider origin() {
    return _provider;
  }

  @override
  Future<bool> availableBluetooth() async {
    return await FlutterBluePlus.isSupported;
  }

  @override
  Future<bool> bluetoothIsEnabled() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  @override
  Future<bool> isConnected() async {
    return _connectedDevice?.connectionState() == ConnectionState.connected;
  }

  @override
  Future<bool> isDiscovery() async {
    return _scanSubscription != null;
  }

  @override
  Stream<BLEBluetoothDevice> discovered() {
    return _discoveryController.stream;
  }

  @override
  Future<void> startDiscovery({
    bool disconnectConnectedDevice = true,
    bool useMac = true,
    Duration timeout = FluetoothConst.defDiscoveryTimeout,
  }) async {
    if (disconnectConnectedDevice && await isConnected()) {
      await _connectedDevice?.disconnect();
    }
    this.useMac = useMac;
    _notifiedDeviceIds.clear();
    await stopDiscovery();

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final device = r.device;
        final id = device.remoteId.str;
        if (_notifiedDeviceIds.contains(id)) continue;
        _notifiedDeviceIds.add(id);
        _discoveryController.add(_Helpers.fromBleScanResult(r, useMac));
      }
    });

    // start scan (flutter_blue_plus will auto-stop on timeout)
    await FlutterBluePlus.startScan(timeout: timeout);
  }

  @override
  Future<void> stopDiscovery() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  @override
  Future<ConnectedDevice> connect(
    BLEBluetoothDevice device, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await stopDiscovery();

    final originDevice = device.origin;
    try {
      await originDevice.connect(
        license: License.free,
        timeout: timeout,
      );
    } catch (e) {
      // already connected or connect failed
      final state = await originDevice.connectionState.first;
      if (state != BluetoothConnectionState.connected) {
        throw Exception("[bluetooth-ble] the printer connect fail: $e");
      }
    }

    final services = await originDevice.discoverServices();
    final selection = _Helpers.selectCharacteristics(
      services,
      allowedServices: _allowedServices,
      allowedCharacteristic: _allowedCharacteristic,
      allowDetectDifferentCharacteristic: _allowDetectDifferentCharacteristic,
    );

    final writeChar = selection.writeCharacteristic;
    final notifyChar = selection.notifyCharacteristic;

    if (writeChar == null && notifyChar == null) {
      throw Exception(
          "[bluetooth-ble] no writable/notify characteristic found");
    }

    _connectedDevice = BLEConnectedDevice(
      device: originDevice,
      connectedDevice: device,
      writeCharacteristic: writeChar,
      notifyCharacteristic: notifyChar,
    );

    return _connectedDevice!;
  }
}

class _Helpers {
  static String _norm(String s) => s.toLowerCase().replaceAll('-', '');

  static BLEBluetoothDevice fromBleScanResult(ScanResult result, bool useMac) {
    final device = result.device;
    final id = device.remoteId.str;
    return BLEBluetoothDevice(
      origin: device,
      name: device.platformName,
      mac: id,
      rssi: result.rssi,
    );
  }

  static bool _serviceAllowed(
      String serviceUuid, List<AllowService>? allowedServices) {
    if (allowedServices == null || allowedServices.isEmpty) return true;
    final actual = _norm(serviceUuid);
    for (final rule in allowedServices) {
      final target = _norm(rule.uuid);
      switch (rule.rule) {
        case AllowRule.equals:
          if (actual == target) return true;
          break;
        case AllowRule.startWith:
          if (actual.startsWith(target)) return true;
          break;
        case AllowRule.endWith:
          if (actual.endsWith(target)) return true;
          break;
        case AllowRule.regex:
          if (RegExp(rule.uuid, caseSensitive: false).hasMatch(serviceUuid)) {
            return true;
          }
          break;
      }
    }
    return false;
  }

  static bool _isWritable(BluetoothCharacteristic c) =>
      c.properties.write || c.properties.writeWithoutResponse;

  static bool _isNotifiable(BluetoothCharacteristic c) =>
      c.properties.notify || c.properties.indicate;

  static _CharacteristicSelection selectCharacteristics(
    List<BluetoothService> services, {
    required List<AllowService>? allowedServices,
    required String? allowedCharacteristic,
    required bool allowDetectDifferentCharacteristic,
  }) {
    final wantedChar =
        allowedCharacteristic == null ? null : _norm(allowedCharacteristic);

    BluetoothCharacteristic? firstWritable;
    BluetoothCharacteristic? firstNotifiable;
    BluetoothCharacteristic? matchedWritable;
    BluetoothCharacteristic? matchedNotifiable;

    for (final s in services) {
      final serviceUuid = s.uuid.str;
      if (!_serviceAllowed(serviceUuid, allowedServices)) continue;
      for (final c in s.characteristics) {
        final cu = _norm(c.uuid.str);
        if (_isWritable(c) && firstWritable == null) firstWritable = c;
        if (_isNotifiable(c) && firstNotifiable == null) firstNotifiable = c;

        if (wantedChar != null && cu == wantedChar) {
          if (_isWritable(c) && matchedWritable == null) matchedWritable = c;
          if (_isNotifiable(c) && matchedNotifiable == null) {
            matchedNotifiable = c;
          }
        }
      }
    }

    if (wantedChar != null) {
      final w = matchedWritable ??
          (allowDetectDifferentCharacteristic ? firstWritable : null);
      final n = matchedNotifiable ?? firstNotifiable;
      return _CharacteristicSelection(
          writeCharacteristic: w, notifyCharacteristic: n);
    }

    return _CharacteristicSelection(
      writeCharacteristic: firstWritable,
      notifyCharacteristic: firstNotifiable ?? firstWritable,
    );
  }
}

class FlutterBluePlusProvider {
  const FlutterBluePlusProvider();
}

class _CharacteristicSelection {
  final BluetoothCharacteristic? writeCharacteristic;
  final BluetoothCharacteristic? notifyCharacteristic;

  const _CharacteristicSelection({
    required this.writeCharacteristic,
    required this.notifyCharacteristic,
  });
}
