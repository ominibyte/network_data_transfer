import 'dart:async';

import 'dart:io';
import 'dart:math' as Math;
import 'dart:convert';
import 'dart:typed_data';

part 'client.dart';
part 'server.dart';
part 'device.dart';
part 'device_discover_listener.dart';
part 'connection_listener.dart';
part 'packet.dart';

/// A Host is a generic station (STA) in the network.
/// A Client and a Server are both hosts
abstract class Host{
  // The default discovery port to listen on if the user does not specify any
  static const int DEFAULT_MULTICAST_PORT = 5018;
  // The multicast group the devices should join
  static const String DEFAULT_MULTICAST_GROUP_IP = "225.225.225.225";
  // TODO later we can allow a range of ports to listen on for discovery
  // The actual multicast discovery port to listen on.
  int _port;
  IPVersion _ipVersion;
  RawDatagramSocket _multicastSocket;
  Completer<bool> _readyCompleter = Completer();
  String _ipAddress;  // The IP address for this host which we will be using
  Set<Device> _discoveredDevices; // Devices that we find during the discovery/handshake
  Map<Device, Socket> _devices;  // These are devices which have connected to us
  Timer _timer;
  String _multicastGroupIP;
  DeviceDiscoveryListener _discoveryListener;
  ConnectionListener _connectionListener;
  String _name; // A name/identifier to give this host

  Host({String name, int multicastPort = DEFAULT_MULTICAST_PORT, String multicastGroupIP = DEFAULT_MULTICAST_GROUP_IP,
    IPVersion ipVersion = IPVersion.any, DeviceDiscoveryListener deviceDiscoveryListener, ConnectionListener connectionListener}){
    assert(multicastPort != null);
    assert(multicastGroupIP != null);
    assert(ipVersion != null);
    assert(_multicastGroupIsValid(multicastGroupIP));

    _name = name;
    _port = multicastPort;
    _ipVersion = ipVersion;
    _multicastGroupIP = multicastGroupIP;
    _discoveryListener = deviceDiscoveryListener;
    _connectionListener = connectionListener;
    _discoveredDevices = Set();
  }

  bool _multicastGroupIsValid(String ip){
    List<String> parts = ip.split(".");
    if( parts.length != 4 )
      return false;
    //224.0.0.0 to 239.255.255.255
    if( int.parse(parts[0]) < 224 || int.parse(parts[0]) > 239 )
      return false;
    if( parts.any((part) => int.parse(part) > 255 || int.parse(part) < 0) )
      return false;
    return !(int.parse(parts[0]) == 224
        && parts.sublist(1).every((part) => int.parse(part) == 0));
  }

  // Hosts can send messages to other devices using the internal socket
  // contained in the Device
  send(Packet packet, Device device) async{
    // check if we have a socket for the device
    if( device.connected && device._socket != null ) {
      if( packet.isStream ) {
        await device._socket.addStream(packet.stream);
        await device._socket.flush();
      }
      else{
        await device._socket.add(packet.bytes);
        await device._socket.flush();
      }
    }
  }


  /// Get the first IP address we find.
  Future<void> _findFirstIPAddress() async =>
    _ipAddress = (await (_ipVersion == IPVersion.any ? ipAddresses :
      _ipVersion == IPVersion.v4 ? ipv4Addresses : ipv6Addresses)).first;


  /// If this device is ready to
  Future<bool> get ready => _readyCompleter.future;

  /// Get all IP addresses for all IP versions
  Future<Iterable<String>> get ipAddresses async => _getAddresses(InternetAddressType.any);
  /// Get all IP addresses for IPv4
  Future<Iterable<String>> get ipv4Addresses async => _getAddresses(InternetAddressType.IPv4);
  /// Get all IP addresses for IPv6
  Future<Iterable<String>> get ipv6Addresses async => _getAddresses(InternetAddressType.IPv6);

  /// Get all IP addresses for specified IP version.
  /// IP addresses are not cached because they could potentially be stale.
  Future<Iterable<String>> _getAddresses(InternetAddressType type) async{
    final interfaces = await NetworkInterface.list(includeLoopback: false,
        type: type);

    return interfaces.where((interface) => interface != null)
        .expand((interface) => interface.addresses)
        .map((address) => address.address);
  }

  set name (String name) => _name = name;
  String get name => _name;

  void disconnect();
}

/// The supported IP version to use
enum IPVersion{
  any, v4, v6
}
