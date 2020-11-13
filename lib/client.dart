part of 'host.dart';

/// A Client connects to a Server and can discover Servers listening on the network
class Client extends Host{
  Socket _socket;
  bool _connected;

  /**
   * See [Host] for explanation on all the common options.
   */
  Client({String name, int multicastPort, String multicastGroupIP, IPVersion ipVersion,
    DeviceDiscoveryListener deviceDiscoveryListener, ConnectionListener connectionListener})
      : super(name: name ?? "Client ${Random().nextInt(1000) + 1}", multicastPort: multicastPort,
          ipVersion: ipVersion,
          deviceDiscoveryListener : deviceDiscoveryListener, connectionListener: connectionListener){
    _connected = false;
    _init();
  }

  Future<void> _init(){
    return _findFirstIPAddress()
        .then<void>((_){
          if( !_readyCompleter.isCompleted )
            _readyCompleter.complete(true);
        }).catchError((e){
          if( !_readyCompleter.isCompleted )
            _readyCompleter.complete(false);
        });
  }

  /// Client searches for AP hosts (Servers).
  /// The Client joins a multicast group to listens for advertisements.
  /// This method returns boolean future that indicates if the client was able to
  /// join the multicast group.
  ///
  /// [precondition] is an optional Check you can specify the Client to make
  /// before continuing. This is useful if there is some long running task that
  /// must be satisfied before the client begins host discovery. [precondition],
  /// if specified must return a boolean value. On some hosts, you may need to
  /// prepare the system to intercept any messages from the multicast group which
  /// is an example of how the optional parameter can be used to handle such requirement
  Future<bool> discoverHosts([Future<bool> precondition]) async{
    if( precondition != null && !await precondition )
      return false;

    // Disconnect just in case we were previously connected to one.
    await _disconnectFromMulticastGroup();

    if( !await _multicastConnect(_multicastPort) )
      return false;

    // Go through all the interfaces and try to join the multicast group for
    // that interface
    for(NetworkInterface interface in await interfaces) {
      try {
        _multicastSocket.joinMulticast(InternetAddress(_multicastGroupIP), interface);
      }
      catch(ignored){}
    }

    _multicastSocket.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram datagram = _multicastSocket.receive();
        if (datagram != null && Packet.from(datagram.data).as<String>().startsWith("PING")) {
          // send the name of the host along side the response
          _multicastSocket.send(
            Packet.from("PONG|$name").bytes,
            datagram.address,
            datagram.port,
          );

          List<String> parts = Packet.from(datagram.data).as<String>().split("|");
          Device device = new Device.from(
            ip: datagram.address.address,
            port: int.tryParse(parts[2]),
            name: parts[1]
          );

          if( !_discoveredDevices.contains(device) ){
            _discoveredDevices.add(device);
            _discoveryListener?.onDiscovery(device, _discoveredDevices);
          }
        }
        else if( datagram != null ){
          _discoveryListener?.onAdvertisement(
            Device(datagram.address.address, datagram.port),
            Packet.fromBytes(datagram.data)
          );
        }
      }
    }, onDone: () async{
      await _disconnectFromMulticastGroup();
      _discoveryListener?.onClose(false, null, null);
    }, onError: (Object error, StackTrace stackTrace) async{
      await _disconnectFromMulticastGroup();
      _discoveryListener?.onClose(true, error, stackTrace);
    }, cancelOnError: true);

    return true;
  }

  /// A way to stop the Client from further listening on multicast discovery messages.
  /// This is particularly useful when you have found the host with the required service.
  void stopDiscovery() => _disconnectFromMulticastGroup();

  /// The client can connect to the Server that is already listening for connection.
  /// [ipAddress] is the IP to use in connecting to the server if the default detected
  /// one is not the interface you want to use.
  /// [ipAddress] is not validated for correctness or if really it is owned by this Device
  /// All IP addresses for host can be obtained using the ipAddresses property
  void connectTo(Device device, {String ipAddress}) async{
    // Disconnect from Server if we have already previously connected
    await _disconnectFromServer();

    // Use the detected IP address to connect to the server
    try {
      //TODO we need to figure out how to set the connecting interface
      _socket = await Socket.connect(device.ip, device.port,
          sourceAddress: ipAddress ?? _ipAddress);
    }
    catch(error, stackTrace){
      _connectionListener?.onDisconnected(device, true, error, stackTrace);
      disconnect();
      return;
    }
    _connected = true;

    device._isConnected = true;
    device._socket = _socket;
    // fire connection listener
    _connectionListener?.onConnected(device);

    _socket.listen((event) {
      _connectionListener?.onMessage(Packet.fromBytes(event), device);
    }, onDone: () async{
      await disconnect(); // disconnect from everything
      // fire disconnection listener
      _connectionListener?.onDisconnected(device, false, null, null);
    }, onError: (Object error, StackTrace stackTrace) async{
      await disconnect(); // disconnect from everything
      // fire disconnection listener
      _connectionListener?.onDisconnected(device, true, error, stackTrace);
    }, cancelOnError: true);
  }

  bool get connected => _connected;

  @override
  Future<void> disconnect() async{
    await _disconnectFromMulticastGroup();
    _disconnectFromServer();
    _discoveredDevices.clear(); // remove all devices found (which should just be one)
  }

  void _disconnectFromMulticastGroup() async{
    if( _multicastSocket == null )
      return;
    for(NetworkInterface interface in await interfaces) {
      try {
        _multicastSocket.leaveMulticast(InternetAddress(_multicastGroupIP), interface);
      }
      catch(ignored){}
    }
    _multicastSocket.close();
  }

  void _disconnectFromServer() async{
    await _socket?.close();
    _socket?.destroy();
    _connected = false;
  }
}