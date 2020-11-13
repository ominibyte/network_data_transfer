part of 'host.dart';

/// A Server listens for connections and keeps a list of all the connected devices
class Server extends Host{
  ServerSocket _serverSocket;
  int _socketPort;  // The port where this server will be listening for reliable communication
  bool _running;
  bool _enableDiscovery;
  // If the user wants to choose the IP address which the Server will listen on,
  // this is the callback that will be used
  ListenOn _listenOn;
  List<RawDatagramSocket> _multicastSockets;
  CustomAdvertisement _customAdvertisement;

  /**
   * [listenOn] Allows you to provide the IP address the server should listen on
   * for Client connections. If none is provided, the Server will listen on all
   * IP address found for the supplied [ipVersion]
   *
   * The optional [customAdvertisement] allows you to specify a custom advertisement message
   * to be sent to the multicast group and received using [CustomAdvertisement.onAdvertisement]
   *
   * [enableDiscovery] is used to inform the Server to broadcast advertisements
   * to a multicast group which will be joined by Clients to allow dynamic port
   * discovery. This means, you would not need to supply a value for [serverSocketPort]
   * because the Server will ask the operating system to provide an available port which it
   * will communicate with the discovered Clients and which the Clients will use for
   * socket connection with the Server.
   *
   * If [serverSocketPort] is specified, the Server will listen on the port specified
   * else it will ask the operating system for a free port which will be used.
   * You should normally specify a [serverSocketPort] if [enableDiscovery] is set to false.
   *
   * See [Host] for explanation on other common options.
   */
  Server({String name, int multicastPort, IPVersion ipVersion, CustomAdvertisement customAdvertisement,
    DeviceDiscoveryListener deviceDiscoveryListener, ConnectionListener connectionListener,
    int serverSocketPort, bool enableDiscovery = true, ListenOn listenOn})
      : super(name: name ?? "Server", multicastPort: multicastPort,
        ipVersion: ipVersion, deviceDiscoveryListener : deviceDiscoveryListener,
        connectionListener : connectionListener){
    _socketPort = serverSocketPort ?? 0;
    _enableDiscovery = enableDiscovery;
    _listenOn = listenOn;
    _multicastSockets = [];
    _customAdvertisement = customAdvertisement;
    // check that the port is within a valid range
    if( _socketPort != 0 ){
      assert(_socketPort > 1024);
      assert(_socketPort < 65535);
    }

    // initialize the needed params
    _init();
  }

  Future<void> _init(){
    // reset the ready completer just in case we may need to call init again on failed start
    _readyCompleter = Completer();
    _running = false;

    // First detect the IP address of the server which we will listen to
    // next, start listening for connections on the socket port
    // before enabling discovery from clients.
    return _findFirstIPAddress()
        .then((_){
          // check if the user wants us to listen on a particular address
          if( _listenOn != null )
            return _listenOn(interfaceAddresses);

          return Future.value(_ipAddress);
        })
        .then((ip) => _ipAddress = ip)
        .then((_) => _listenForConnections())
        .then((_) => _enableDiscovery ? _startAdvertisement() : null)
        .then<void>((_){
          if( !_readyCompleter.isCompleted )
            _readyCompleter.complete(true);
        }).catchError((e){
          if( !_readyCompleter.isCompleted )
            _readyCompleter.complete(false);
        });
  }

  // server automatically listens for client incoming connections
  Future<void> _listenForConnections() async{
    try{
      _serverSocket = await ServerSocket.bind(_listenOn == null ? (_ipVersion == IPVersion.any ? InternetAddressType.any :
      _ipVersion == IPVersion.v4 ? InternetAddress.anyIPv4 :
      InternetAddress.anyIPv6) : _ipAddress, _socketPort);
    }
    catch(error, stackTrace){
      _connectionListener?.onDisconnected(null, true, error, stackTrace);
      return;
    }
    _running = true;

    // Update the port just in case no port was specified for connection
    _socketPort = _serverSocket.port;
    _serverSocket.listen(
      _processSocket,
      onError: (Object error, StackTrace stackTrace){
        _running = false;
        _connectionListener?.onDisconnected(null, false, error, stackTrace);
      },
      onDone: (){
        _running = false;
        _connectionListener?.onDisconnected(null, false, null, null);
      },
      cancelOnError: true
    );
  }

  // Handle the new connection
  void _processSocket(Socket socket){
    // Check if we have a device with this IP address
    Device device = new Device(socket.remoteAddress.address, socket.remotePort);
    // Inform any listener if this device is new. This means this device didn't use
    // The discovery mode for connection. The server might likely be using a static IP
    if( !_discoveredDevices.contains(device) ){
      _discoveredDevices.add(device);
      _discoveryListener?.onDiscovery(device, _discoveredDevices);
    }
    else  // get the current device from discovered devices and set the connection details
      device = _discoveredDevices.lookup(device);

    device._isConnected = true;
    device._socket = socket;
    // fire connection listener
    _connectionListener?.onConnected(device);
    
    socket.listen((event) {
      _connectionListener?.onMessage(Packet.fromBytes(event), device);
    }, onDone: (){
      socket.destroy();
      device._connected = null;
      // fire disconnection listener
      _connectionListener?.onDisconnected(device, false, null, null);
    },onError: (Object error, StackTrace stackTrace){
      socket.destroy();
      device._connected = null;
      // fire disconnection listener
      _connectionListener?.onDisconnected(device, false, error, stackTrace);
    }, cancelOnError: true);
  }

  Future<void> _startAdvertisement() async {
    // Stop discovery if we happen to already be advertising
    stopDiscovery();

    if( !await _multicastConnect(0) )
      return;

    // We shouldn't be able to send to InternetAddress.anyIPv6
    if( _ipVersion != IPVersion.v6 )
      _multicastSockets.add(_multicastSocket);

    for(NetworkInterface interface in await interfaces) {
      // Use the first address reported by the interface
      final InternetAddress address = interface.addresses[0];

      try {
        // Lets create a multicast socket for each adapter to we can be able to
        // send multicast
        RawDatagramSocket s = await RawDatagramSocket.bind(
            address,
            _multicastPort, // _multicastPort or 0
            reuseAddress: true,
            reusePort: false)
          ..broadcastEnabled = true
          ..readEventsEnabled = true;

        _multicastSockets.add(s);

        if( address.type == InternetAddressType.IPv4 ){
          _multicastSocket.setRawOption(RawSocketOption(
              RawSocketOption.levelIPv4,
              RawSocketOption.IPv4MulticastInterface,
              address.rawAddress
          ));
        }
        else{
          _multicastSocket.setRawOption(RawSocketOption.fromInt(
              RawSocketOption.levelIPv6,
              RawSocketOption.IPv6MulticastInterface,
              interface.index
          ));
        }
      }
      catch(ignored){}
    }

    // we listen on all addresses
    _multicastSocket.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram datagram = _multicastSocket.receive();
        if (datagram != null && Packet.from(datagram.data).as<String>().startsWith("PONG")){
          List<String> parts = Packet.from(datagram.data).as<String>().split("|");
          Device device = new Device(datagram.address.address, datagram.port)
            ..name = parts[1];
          if( !_discoveredDevices.contains(device) ){
            _discoveredDevices.add(device);
            _discoveryListener?.onDiscovery(device, _discoveredDevices);
          }
        }
      }
    }, onDone: (){
      stopDiscovery();
      _discoveryListener?.onClose(false, null, null);
    }, onError: (Object error, StackTrace stackTrace){
      stopDiscovery();
      _discoveryListener?.onClose(true, error, stackTrace);
    }, cancelOnError: false);

    // Start the timer to send periodic messages on the multicast channel
    _startAdvertisementTimer();
  }

  void _startAdvertisementTimer(){
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if ( _timer.isActive ) {
        // We send to all interface multicast sockets
        for( RawDatagramSocket s in _multicastSockets ){
          // If a custom advertisement is provided, send that else send the internal
          // communication message
          s.send(
            _customAdvertisement != null ? _customAdvertisement(_socketPort)
              // send the name of this host and the listening port for reliable
              //connection along with the PING message
                : Packet.from("PING|$name|$_socketPort").bytes,
            InternetAddress(_multicastGroupIP),
            _multicastPort,
          );
        }
      }
    });
  }

  /// Send a broadcast using either the multicast group for unreliable
  /// and the connected client sockets for reliable broadcast
  Future<void> broadcast(Packet packet, {bool reliable = false}) async{
    bool isReady = await ready;
    if( !isReady )
      throw "Host failed to start";
    else if( _ipAddress == null )
      throw "Unable to detect host IP address";
    else if( _multicastSocket != null && !reliable ){ // multicast broadcast
      for( RawDatagramSocket s in _multicastSockets ){
        s.send(
          packet.bytes,
          _ipAddress.contains(".") ?
              InternetAddress(_ipAddress.split(".").sublist(0, 3).join(".") + ".255") :
              _multicastGroupIP,
          _multicastPort
        );
      }
    }
    else if( _serverSocket != null && reliable ){ // reliable broadcast
      // send reliable broadcast using all connected client sockets
      for(Device device in _discoveredDevices)
        send(packet, device, ignoreIfNotConnected: true);
    }
  }

  int get port => _socketPort;
  bool get running => _running;

  /// Shutdown the Server by Disconnecting from all sockets
  @override
  Future<void> disconnect() async{
    stopDiscovery();
    await _serverSocket?.close();
    // disconnect with all the devices which we have open sockets with
    for( Device device in _discoveredDevices ) {
      await device._socket?.close();
      device._socket?.destroy();
    }
    _running = false;
    _discoveredDevices.clear(); // remove all devices found
  }

  /// (Re)Start advertisements from this server to enable discovery on Clients
  void startDiscovery() async => await _startAdvertisement();

  /// This allows pausing the discovery advertisements
  void pauseDiscovery() => _stopAdvertisementTimer();

  /// You can resumed a paused discovery advertisement
  void resumeDiscovery(){
    if( _timer == null || !_timer.isActive )
      _startAdvertisement();
  }

  /// Stop this Server from Advertising for Client discovery
  void stopDiscovery(){
    _stopAdvertisementTimer();

    for( RawDatagramSocket s in _multicastSockets )
      s.close();

    _multicastSocket?.close();
    _multicastSocket = null;
  }

  void _stopAdvertisementTimer(){
    _timer?.cancel();
    _timer = null;
  }

}

/// For the socket connection to the Server, this allows you to specify the IP address
/// which the Server should listen on.
///
/// Based on the IPVersion passed to the Server (defaults to all), you will receive
/// [interfaceAddresses] which will give all IP addresses found for all interfaces.
/// You can decide to choose and return one IP address from all discovered.
/// The chosen IP Address will be used by the Server to listen for client connections.
/// If the ListenOn option is not specified during the creation of the
/// Server, the Server will listen on all of the discovered IP addresses.
typedef ListenOn = Future<String> Function(Future<Iterable<Map<NetworkInterface, Iterable<InternetAddress>>>> interfaceAddresses);

/// This is used to create a custom advertisement message.
///
/// [socketPort] is the port which the Server is listening. If you pass a serverSocketPort
/// to [Server], [socketPort] will be the same value else it will be the one assigned
/// by the operating system.
///
/// This should return a [Packet] which will be sent out as the advertisement
/// to all the [Client]s.
typedef CustomAdvertisement = Packet Function(int socketPort);