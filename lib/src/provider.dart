part of 'package:bluetooth_ble/bluetooth_ble.dart';

/// ble bluetooth provider
class BLEBluetooth extends Fluetooth<UniversalBleProvider, BLEBluetoothDevice> {
  final UniversalBleProvider _provider = const UniversalBleProvider();
  final _discoveryController = StreamController<BLEBluetoothDevice>.broadcast();
  BLEConnectedDevice? _connectedDevice;
  final Set<String> _notifiedDeviceIds = <String>{};
  static BLEBluetooth? _bleBluetooth;
  StreamSubscription<BleDevice>? _scanSubscription;
  final bool _debugLog = true;

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
  UniversalBleProvider origin() {
    return _provider;
  }

  @override
  Future<bool> availableBluetooth() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return state == AvailabilityState.poweredOn;
  }

  @override
  Future<bool> bluetoothIsEnabled() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return state == AvailabilityState.poweredOn;
  }

  @override
  Future<bool> isConnected() async {
    return _connectedDevice?.connectionState() == ConnectionState.connected;
  }

  @override
  Future<bool> isDiscovery() async {
    try {
      return await UniversalBle.isScanning();
    } catch (_) {
      return _scanSubscription != null;
    }
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

    // Ensure permissions (Android/iOS); on desktop/web it will succeed/no-op.
    final hasPerm =
        await UniversalBle.hasPermissions(withAndroidFineLocation: true);
    if (!hasPerm) {
      await UniversalBle.requestPermissions(withAndroidFineLocation: true);
    }

    if (_debugLog) {
      print('[bluetooth-ble] startDiscovery timeout=$timeout');
    }

    _scanSubscription = UniversalBle.scanStream.listen((d) {
      final id = d.deviceId;
      if (_notifiedDeviceIds.contains(id)) return;
      _notifiedDeviceIds.add(id);
      if (_debugLog) {
        print(
          '[bluetooth-ble] found name="${d.name}" id=$id rssi=${d.rssi}',
        );
      }
      _discoveryController.add(_Helpers.fromBleDevice(d));
    });

    await UniversalBle.startScan();

    // universal_ble does not auto-stop on timeout: stop manually
    Timer(timeout, () {
      // ignore: discarded_futures
      stopDiscovery();
    });
  }

  @override
  Future<void> stopDiscovery() async {
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
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
    final deviceId = originDevice.deviceId;
    if (_debugLog) {
      print('[bluetooth-ble] connect name="${device.name}" id=$deviceId');
    }

    await UniversalBle.connect(deviceId, timeout: timeout);

    final services = await UniversalBle.discoverServices(deviceId);
    if (_debugLog) {
      print('[bluetooth-ble] services count=${services.length}');
      for (final s in services) {
        print('[bluetooth-ble]  service ${s.uuid}');
        for (final c in s.characteristics) {
          // Avoid using enum.name (requires Dart >= 2.15)
          final props = c.properties.map((e) => e.toString()).join(',');
          print('[bluetooth-ble]   char ${c.uuid} props=[$props]');
        }
      }
    }
    final selection = _Helpers.selectCharacteristics(
      services,
      allowedServices: _allowedServices,
      allowedCharacteristic: _allowedCharacteristic,
      allowDetectDifferentCharacteristic: _allowDetectDifferentCharacteristic,
    );

    final write = selection.write;
    final notify = selection.notify;
    if (_debugLog) {
      print(
        '[bluetooth-ble] selected write=${write?.characteristic.uuid}@${write?.serviceUuid} '
        'notify=${notify?.characteristic.uuid}@${notify?.serviceUuid}',
      );
    }

    if (write == null && notify == null) {
      throw Exception(
          "[bluetooth-ble] no writable/notify characteristic found");
    }

    _connectedDevice = BLEConnectedDevice(
      deviceId: deviceId,
      connectedDevice: device,
      write: write,
      notify: notify,
    );

    return _connectedDevice!;
  }
}

class _Helpers {
  static String _norm(String s) => s.toLowerCase().replaceAll('-', '');

  static BLEBluetoothDevice fromBleDevice(BleDevice device) {
    final id = device.deviceId;
    return BLEBluetoothDevice(
      origin: device,
      name: device.name,
      mac: id,
      rssi: device.rssi,
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

  static bool _isWritable(BleCharacteristic c) =>
      c.properties.contains(CharacteristicProperty.write) ||
      c.properties.contains(CharacteristicProperty.writeWithoutResponse);

  static bool _isNotifiable(BleCharacteristic c) =>
      c.properties.contains(CharacteristicProperty.notify) ||
      c.properties.contains(CharacteristicProperty.indicate);

  static _CharacteristicSelection selectCharacteristics(
    List<BleService> services, {
    required List<AllowService>? allowedServices,
    required String? allowedCharacteristic,
    required bool allowDetectDifferentCharacteristic,
  }) {
    final wantedChar =
        allowedCharacteristic == null ? null : _norm(allowedCharacteristic);

    BleQualifiedCharacteristic? firstWritable;
    BleQualifiedCharacteristic? firstNotifiable;
    BleQualifiedCharacteristic? matchedWritable;
    BleQualifiedCharacteristic? matchedNotifiable;

    for (final s in services) {
      final serviceUuid = s.uuid;
      if (!_serviceAllowed(serviceUuid, allowedServices)) continue;
      for (final c in s.characteristics) {
        final cu = _norm(c.uuid);
        if (_isWritable(c) && firstWritable == null) {
          firstWritable = BleQualifiedCharacteristic(serviceUuid, c);
        }
        if (_isNotifiable(c) && firstNotifiable == null) {
          firstNotifiable = BleQualifiedCharacteristic(serviceUuid, c);
        }

        if (wantedChar != null && cu == wantedChar) {
          if (_isWritable(c) && matchedWritable == null) {
            matchedWritable = BleQualifiedCharacteristic(serviceUuid, c);
          }
          if (_isNotifiable(c) && matchedNotifiable == null) {
            matchedNotifiable = BleQualifiedCharacteristic(serviceUuid, c);
          }
        }
      }
    }

    if (wantedChar != null) {
      final w = matchedWritable ??
          (allowDetectDifferentCharacteristic ? firstWritable : null);
      final n = matchedNotifiable ?? firstNotifiable;
      return _CharacteristicSelection(write: w, notify: n);
    }

    return _CharacteristicSelection(
      write: firstWritable,
      notify: firstNotifiable ?? firstWritable,
    );
  }
}

class UniversalBleProvider {
  const UniversalBleProvider();
}

class _CharacteristicSelection {
  final BleQualifiedCharacteristic? write;
  final BleQualifiedCharacteristic? notify;

  const _CharacteristicSelection({
    required this.write,
    required this.notify,
  });
}

class BleQualifiedCharacteristic {
  final String serviceUuid;
  final BleCharacteristic characteristic;
  const BleQualifiedCharacteristic(this.serviceUuid, this.characteristic);
}
