import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/sensors/ble/ble_device_manager.dart';
import '../../../../data/sensors/ble/heart_rate_ble_adapter.dart';
import '../../../../data/sensors/iot/esp32_environment_adapter.dart';
import '../../../../data/sensors/models/twin_sensor_signals.dart';
import '../../../../data/sensors/twin_sensor_coordinator.dart';

/// Modal bottom sheet allowing users to scan, discover, connect, and monitor
/// Bluetooth Low Energy (BLE) health devices and ESP32 environmental nodes.
class BleDeviceManagerSheet extends StatefulWidget {
  final TwinSensorCoordinator coordinator;

  const BleDeviceManagerSheet({
    super.key,
    required this.coordinator,
  });

  static Future<void> show(BuildContext context, TwinSensorCoordinator coordinator) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BleDeviceManagerSheet(coordinator: coordinator),
    );
  }

  @override
  State<BleDeviceManagerSheet> createState() => _BleDeviceManagerSheetState();
}

class _BleDeviceManagerSheetState extends State<BleDeviceManagerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<DiscoveredBleDevice> _discoveredDevices = [];
  StreamSubscription<DiscoveredBleDevice>? _scanSubscription;
  bool _isScanning = false;
  String? _connectingDeviceId;
  String? _errorMessage;
  BlePermissionReport? _lastPermissionReport;
  Timer? _ticker;

  HeartRateBleAdapter get _hrAdapter => widget.coordinator.heartRateAdapter;
  Esp32EnvironmentAdapter get _esp32Adapter => widget.coordinator.esp32Adapter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_isScanning) {
        _stopScan();
        _startScan();
      }
    });
    // Ticker to refresh "X seconds ago" freshness labels
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stopScan();
    _ticker?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
      _errorMessage = null;
      _lastPermissionReport = null;
    });

    try {
      final report = await widget.coordinator.bleManager.checkAndRequestPermissions();
      if (!report.isGranted) {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _lastPermissionReport = report;
            _errorMessage = report.message;
          });
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _errorMessage = 'Permission check failed: $e';
        });
      }
      return;
    }

    final stream = _tabController.index == 0
        ? _hrAdapter.scanForHeartRateMonitors(duration: const Duration(seconds: 15))
        : _esp32Adapter.scanForEsp32Sensors(duration: const Duration(seconds: 15));

    _scanSubscription = stream.listen(
      (device) {
        if (mounted) {
          setState(() {
            final idx = _discoveredDevices.indexWhere((d) => d.id == device.id);
            if (idx >= 0) {
              _discoveredDevices[idx] = device;
            } else {
              _discoveredDevices.add(device);
            }
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _errorMessage = 'Bluetooth scan error: $err. Check permissions and Bluetooth power.';
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _isScanning = false);
        }
      },
    );
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    if (_isScanning) {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToDevice(String deviceId) async {
    _stopScan();
    setState(() {
      _connectingDeviceId = deviceId;
      _errorMessage = null;
    });

    try {
      if (_tabController.index == 0) {
        await _hrAdapter.connect(deviceId);
      } else {
        await _esp32Adapter.connect(deviceId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Connection failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _connectingDeviceId = null);
      }
    }
  }

  Future<void> _disconnectDevice(bool isHr) async {
    try {
      if (isHr) {
        await _hrAdapter.disconnect();
      } else {
        await _esp32Adapter.disconnect();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Disconnect error: $e');
      }
    }
  }

  String _formatFreshness(DateTime? dt) {
    if (dt == null) return 'No data received';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 3) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Color _getStatusColor(BleDeviceStatus status) {
    switch (status) {
      case BleDeviceStatus.connected:
        return const Color(0xFF10B981); // Emerald green
      case BleDeviceStatus.reconnecting:
        return const Color(0xFFF59E0B); // Amber
      case BleDeviceStatus.stale:
        return const Color(0xFFEAB308); // Yellow
      case BleDeviceStatus.connecting:
      case BleDeviceStatus.scanning:
        return const Color(0xFF3B82F6); // Blue
      case BleDeviceStatus.error:
        return const Color(0xFFEF4444); // Red
      case BleDeviceStatus.disconnected:
      case BleDeviceStatus.disconnecting:
        return const Color(0xFF6B7280); // Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1120) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.bluetooth, size: 20, color: Color(0xFF3B82F6)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BLE Device Manager',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.navy,
                              ),
                            ),
                            Text(
                              'Direct hardware integration & telemetry',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF3B82F6),
            unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
            indicatorColor: const Color(0xFF3B82F6),
            tabs: const [
              Tab(icon: Icon(LucideIcons.heartPulse, size: 18), text: 'Heart Rate (0x180D)'),
              Tab(icon: Icon(LucideIcons.thermometer, size: 18), text: 'ESP32 Climate (0x181A)'),
            ],
          ),

          // Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDeviceTab(isHr: true),
                _buildDeviceTab(isHr: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTab({required bool isHr}) {
    final status = isHr ? _hrAdapter.currentStatus : _esp32Adapter.currentStatus;
    final connectedId = isHr ? _hrAdapter.connectedDeviceId : _esp32Adapter.connectedDeviceId;
    final lastReading = isHr ? _hrAdapter.lastReadingTime : _esp32Adapter.lastReadingTime;
    final isConnected = status == BleDeviceStatus.connected ||
        status == BleDeviceStatus.stale ||
        status == BleDeviceStatus.reconnecting;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Connected Device Card (if any)
        if (isConnected && connectedId != null) ...[
          _buildConnectedCard(isHr: isHr, deviceId: connectedId, status: status, lastReading: lastReading),
          const SizedBox(height: 20),
        ],

        // Error message if any
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade300, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.alertTriangle, size: 20, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_lastPermissionReport?.permanentlyDenied == true)
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await openAppSettings();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red.shade900,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(LucideIcons.settings, size: 14),
                        label: const Text('Open App Settings', style: TextStyle(fontSize: 12)),
                      ),
                    if (_lastPermissionReport != null && !_lastPermissionReport!.locationServiceEnabled)
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await Geolocator.openLocationSettings();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber.shade100,
                          foregroundColor: Colors.amber.shade900,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(LucideIcons.mapPin, size: 14),
                        label: const Text('Enable Location Settings', style: TextStyle(fontSize: 12)),
                      ),
                    OutlinedButton.icon(
                      onPressed: _startScan,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                        side: const BorderSide(color: Color(0xFF3B82F6)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(LucideIcons.refreshCw, size: 14),
                      label: const Text('Retry Scan', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Scanner Control
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Discovered Peripherals',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.navy,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isScanning ? _stopScan : _startScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScanning ? Colors.red.shade700 : const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isScanning
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.search, size: 14),
              label: Text(_isScanning ? 'Stop Scan' : 'Scan for Devices'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Discovered list
        if (_discoveredDevices.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(LucideIcons.bluetoothSearching, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    _isScanning ? 'Scanning for nearby peripherals...' : 'No peripherals discovered yet.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isHr
                        ? 'Ensure your Heart Rate chest strap or watch is powered on.'
                        : 'Ensure your ESP32 node is broadcasting on 0x181A.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          )
        else
          ..._discoveredDevices.map((device) => _buildDiscoveredTile(device, isHr: isHr)),
      ],
    );
  }

  Widget _buildConnectedCard({
    required bool isHr,
    required String deviceId,
    required BleDeviceStatus status,
    required DateTime? lastReading,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: () => _disconnectDevice(isHr),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Disconnect', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isHr ? 'Heart Rate Monitor' : 'ESP32 Climate Sensor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.navy,
            ),
          ),
          Text(
            'Device ID: $deviceId',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Live values & Freshness
          if (isHr) ...[
            ValueListenableBuilder<NormalizedHeartRate?>(
              valueListenable: widget.coordinator.currentHeartRateNotifier,
              builder: (ctx, hr, _) {
                final bpm = hr?.bpm.toInt();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.heartPulse, size: 20, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Text(
                          bpm != null ? '$bpm BPM' : '-- BPM',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.navy,
                          ),
                        ),
                        if (hr?.sensorLocation != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              hr!.sensorLocation!,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatFreshness(lastReading),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: status == BleDeviceStatus.stale ? const Color(0xFFEAB308) : Colors.grey,
                      ),
                    ),
                  ],
                );
              },
            ),
          ] else ...[
            ValueListenableBuilder<double?>(
              valueListenable: widget.coordinator.currentTemperatureNotifier,
              builder: (ctx, temp, _) {
                return ValueListenableBuilder<double?>(
                  valueListenable: widget.coordinator.currentHumidityNotifier,
                  builder: (ctx, hum, _) {
                    final tempStr = temp != null ? '${temp.toStringAsFixed(1)} °C' : '-- °C';
                    final humStr = hum != null ? '${hum.toStringAsFixed(0)} %' : '-- %';
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$tempStr • $humStr',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.navy,
                          ),
                        ),
                        Text(
                          _formatFreshness(lastReading),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: status == BleDeviceStatus.stale ? const Color(0xFFEAB308) : Colors.grey,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscoveredTile(DiscoveredBleDevice device, {required bool isHr}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConnecting = _connectingDeviceId == device.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isHr ? LucideIcons.heartPulse : LucideIcons.cpu,
              size: 18,
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      device.id.length > 17 ? '${device.id.substring(0, 17)}...' : device.id,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white54 : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${device.rssi} dBm',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: isConnecting ? null : () => _connectToDevice(device.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: isConnecting
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Connect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
