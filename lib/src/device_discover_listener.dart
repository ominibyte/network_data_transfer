part of 'host.dart';

abstract class DeviceDiscoveryListener{
  onDiscovery(Device newDevice, Iterable<Device> allDevices);
}