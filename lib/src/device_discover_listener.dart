part of 'host.dart';

abstract class DeviceDiscoveryListener{
  /// This method is called when a new device is discovered. The latest discovered
  /// device is provided as [newDevice]. For convenience, all discovered devices are
  /// also sent to this method as [allDevices]. This method would not be recalled
  /// if a device disconnect and reconnects. For active connection and disconnections
  /// events, use [ConnectionListener.onConnected] and [ConnectionListener.onDisconnected]
  /// respectively.
  onDiscovery(Device newDevice, Iterable<Device> allDevices);

  /// When the multicast connection closes either normally or due to an error,
  /// this method is called. If the connection closed without error, [isError]
  /// will be false. If an error occurred, you can retrieve the error using
  /// [error]. [stackTrace] may be null is the error provider does not send one.
  onClose(bool isError, Object error, StackTrace stackTrace);
}