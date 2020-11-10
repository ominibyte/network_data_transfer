part of 'host.dart';

class Client extends Host{
  Socket _socket;

  Client({String name, int multicastPort, String multicastGroupIP, IPVersion ipVersion,
    DeviceDiscoveryListener deviceDiscoveryListener})
      : super(multicastPort: multicastPort, multicastGroupIP : multicastGroupIP, ipVersion: ipVersion,
          deviceDiscoveryListener : deviceDiscoveryListener, name: name){

    _findFirstIPAddress().then<void>((_){
      if( !_readyCompleter.isCompleted )
        _readyCompleter.complete(true);
    });
  }

  /// client searches for AP hosts (Servers)
  Future<void> discoverHosts() async{
    _multicastSocket = await RawDatagramSocket.bind(
        _ipVersion == IPVersion.any ? InternetAddressType.any :
        _ipVersion == IPVersion.v4 ? InternetAddress.anyIPv4 :
        InternetAddress.anyIPv6, 0) // _port
      ..broadcastEnabled = true;
    _multicastSocket.readEventsEnabled = true;
    _multicastSocket.joinMulticast( InternetAddress( _multicastGroupIP ) );
    _multicastSocket.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram datagram = _multicastSocket.receive();
        if (datagram != null && Packet.from(datagram.data).as<String>() == "PING") {
          //TODO send the name of the device along side the response
          _multicastSocket.send(
            Packet.from("PONG").bytes,
            datagram.address,
            datagram.port,
          );

          Device device = new Device(datagram.address.address, datagram.port);
          if( !_discoveredDevices.contains(device) ){
            _discoveredDevices.add(device);
            _listener?.onDiscovery(device, _discoveredDevices);
          }
        }
      }
    }, onDone: (){}, onError: (){});
  }

  /// The client can connect to the Server that is already listening for connection
  void connectTo(Device device) async{
    // Use the detected IP address to connect to the server
    Socket socket = await Socket.connect(device.ip, device.port, sourceAddress: _ipAddress);
    if( socket == null )
      throw "Could not connect to the Server at ${device.ip}:${device.port}. Please try again later.";

    device._isConnected = true;
    device._socket = socket;

  }

  @override
  void disconnect() {
    _multicastSocket?.leaveMulticast(InternetAddress( _multicastGroupIP ));
    _multicastSocket?.close();
  }
}