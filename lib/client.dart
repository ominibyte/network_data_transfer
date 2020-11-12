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
      : super(name: name, multicastPort: multicastPort, multicastGroupIP : multicastGroupIP, ipVersion: ipVersion,
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
  ///
  /// [precondition] is an optional Check you can specify the Client to make
  /// before continuing. This is useful if there is some long running task that
  /// must be satisfied before the client begins host discovery. [precondition],
  /// if specified must return a boolean value. On some hosts, you may need to
  /// prepare the system to intercept any messages from the multicast group which
  /// is an example of how the optional parameter can be used to handle such requirement
  Future<void> discoverHosts([Future<bool> precondition]) async{
    if( precondition != null && !await precondition )
      return;

    // Disconnect just in case we were previously connected to one.
    _disconnectFromMulticastGroup();

    _multicastSocket = await RawDatagramSocket.bind(
        _ipVersion == IPVersion.any ? InternetAddressType.any :
        _ipVersion == IPVersion.v4 ? InternetAddress.anyIPv4 :
        InternetAddress.anyIPv6,
        _multicastPort, // _multicastPort or 0
        reusePort: false)
      ..broadcastEnabled = true;
    _multicastSocket.readEventsEnabled = true;
    _multicastSocket.joinMulticast( InternetAddress( _multicastGroupIP ) );
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
      }
    }, onDone: (){
      _disconnectFromMulticastGroup();
      _discoveryListener?.onClose(false, null, null);
    }, onError: (Object error, StackTrace stackTrace){
      _disconnectFromMulticastGroup();
      _discoveryListener?.onClose(true, error, stackTrace);
    }, cancelOnError: true);
  }

  /// The client can connect to the Server that is already listening for connection.
  /// [ipAddress] is the IP to use in connecting to the server if the default detected
  /// one is not the interface you want to use.
  /// [ipAddress] is not validated for correctness or if really it is owned by this Device
  /// All IP addresses for host can be obtained using the ipAddresses property
  void connectTo(Device device, {String ipAddress}) async{
    // Disconnect from Server if we have already previously connected
    await _disconnectFromServer();

    // Use the detected IP address to connect to the server
    _socket = await Socket.connect(device.ip, device.port, sourceAddress: ipAddress ?? _ipAddress);
    if( _socket == null )
      throw "Could not connect to the Server at ${device.ip}:${device.port}. Please try again later.";
    _connected = true;
    device._isConnected = true;
    device._socket = _socket;
    // fire connection listener
    _connectionListener?.onConnected(device);

    _socket.listen((event) {
      _connectionListener?.onMessage(Packet.fromBytes(event), device);
    }, onDone: (){
      // _socket.destroy();
      // device._connected = null;
      // _connected = false;
      // fire disconnection listener
      _connectionListener?.onDisconnected(device, false, null, null);
      disconnect(); // disconnect from everything
    }, onError: (Object error, StackTrace stackTrace){
      // _socket.destroy();
      // device._connected = null;
      // _connected = false;
      // fire disconnection listener
      _connectionListener?.onDisconnected(device, true, error, stackTrace);
      disconnect(); // disconnect from everything
    }, cancelOnError: true);
  }

  bool get connected => _connected;

  @override
  void disconnect() async{
    _disconnectFromMulticastGroup();
    _disconnectFromServer();
    _discoveredDevices.clear(); // remove all devices found (which should just be one)
  }

  void _disconnectFromMulticastGroup(){
    _multicastSocket?.leaveMulticast(InternetAddress( _multicastGroupIP ));
    _multicastSocket?.close();
  }

  void _disconnectFromServer() async{
    await _socket?.close();
    _socket?.destroy();
    _connected = false;
  }
}