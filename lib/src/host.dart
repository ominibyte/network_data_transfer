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
  int _multicastPort;
  IPVersion _ipVersion;
  RawDatagramSocket _multicastSocket;
  Completer<bool> _readyCompleter = Completer();
  String _ipAddress;  // The IP address for this host which we will be using
  Set<Device> _discoveredDevices; // Devices that we find during the discovery/handshake
  Timer _timer;
  String _multicastGroupIP;
  DeviceDiscoveryListener _discoveryListener;
  ConnectionListener _connectionListener;
  String _name; // A name/identifier to give this host

  /**
   * [name] is useful for host/device identification purposes especially if discovery
   * is enabled. If you specify a name, the name will be sent to communicating devices
   * to add as a user friendly name during discovery.
   *
   * You can specify a [multicastPort] if you want to use something else instead
   * of the default 5018. This is the port that the multicast group will be listening on.
   * You only need to set this if you plan to enable device discovery and advertisements.
   *
   * [multicastGroupIP] is the Multicast IP address for the multicast group. The
   * default is 225.225.225.225 but it can be changed to a valid multicast address.
   * assert is used to validate the multicast address which should be in the
   * range: 224.0.0.0 to 239.255.255.255 (actually 224.0.0.1 to 239.255.255.254)
   *
   * [ipVersion] is the version of IP to use for all addresses. Options are:
   * IPVersion.any, IPVersion.v4, and IPVersion.v6
   *
   * If you enable discovery, you should provide a [DeviceDiscoveryListener]
   * option to receive connection and disconnection events.
   *
   * You should normally provide a [ConnectionListener] to receive events on
   * connection and disconnection.
   */
  Host({String name, int multicastPort, String multicastGroupIP, IPVersion ipVersion,
    DeviceDiscoveryListener deviceDiscoveryListener, ConnectionListener connectionListener}){
    _name = name?.replaceAll("|", "_") ?? "<Unknown Host>";
    _multicastPort = multicastPort ?? DEFAULT_MULTICAST_PORT;
    _ipVersion = ipVersion ?? IPVersion.any;
    _multicastGroupIP = multicastGroupIP ?? DEFAULT_MULTICAST_GROUP_IP;
    _discoveryListener = deviceDiscoveryListener;
    _connectionListener = connectionListener;
    _discoveredDevices = Set();

    assert(_multicastGroupIsValid(multicastGroupIP), "multicastGroupIP is not valid!");
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

  /// Hosts can send messages to other devices using the internal socket
  /// contained in the Device.
  ///
  /// When [ignoreIfNotConnected] is set to true, If the device is not connected,
  /// it will be silently ignore. If however the value is false which is the
  /// default, an Exception will be thrown.
  send(Packet packet, Device device, {bool ignoreIfNotConnected = false}) async{
    // check if we have a socket for the device
    if( device.connected ) {
      if( packet.isStream ) {
        await device._socket.addStream(packet.stream);
        await device._socket.flush();
      }
      else{
        await device._socket.add(packet.bytes);
        await device._socket.flush();
      }
    }
    else if( !ignoreIfNotConnected )
      throw "Cannot send message. There is no socket connection to this Device.";
  }


  /// Get the first IP address we find.
  Future<void> _findFirstIPAddress() async {
    _ipAddress = (await (_ipVersion == IPVersion.any ? ipAddresses :
        _ipVersion == IPVersion.v4 ? ipv4Addresses : ipv6Addresses)).first;
  }


  /// If this device is ready to
  Future<bool> get ready => _readyCompleter.future;

  /// Get the detected IP address
  String get ipAddress => _ipAddress;

  /// Get the multicast Group IP Address
  String get multicastIPAddress => _multicastGroupIP;

  /// Get the multicast port
  int get multicastPort => _multicastPort;

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

  /// Set the name of this Host. Useful for identification purposes. This will be
  /// sent to all other communicating devices as the name of the host
  set name (String name) => _name = name;
  /// Get the name of this Host. Must have been set using the set property or constructor
  String get name => _name;

  void disconnect();
}

/// The supported IP version to use
enum IPVersion{
  any, v4, v6
}
