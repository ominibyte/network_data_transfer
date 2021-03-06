import 'dart:io';

import 'package:network_data_transfer/host.dart';
import 'package:english_words/english_words.dart';

Iterable<Device> devices;
Server server;

void main() async{
  server = Server(
    ipVersion: IPVersion.v4,
    name: "Server",
    deviceDiscoveryListener: MyDiscoveryListener(),
    connectionListener: MyConnectionListener(),
    listenOn: useFirstFoundIP // Optional. Do not provide to listen on all ip addresses
  );

  if(!await server.ready){
    print("Could not connect on Server");
    return;
  }
  print("Server is ready at ${server.ipAddress}:${server.port}");
}

// Use the first IP address we find for the first interface
Future<String> useFirstFoundIP(Future<Iterable<Map<NetworkInterface, Iterable<InternetAddress>>>> interfaceAddresses) async{
  Iterable<Map<NetworkInterface, Iterable<InternetAddress>>> addressList = await interfaceAddresses;
  return addressList.first.values.first.first.address;
}

class MyDiscoveryListener implements DeviceDiscoveryListener{
  @override
  onDiscovery(Device newDevice, Iterable<Device> allDevices) {
    print("New Client Device Alert: $newDevice");
    devices = allDevices;
  }

  @override
  onClose(bool isError, Object error, StackTrace stackTrace){
    print("Discovery multicast socket closed");
  }

  @override
  void onAdvertisement(Device device, Packet packet) {
  }
}

class MyConnectionListener implements ConnectionListener{
  @override
  void onConnected(Device device) {
    print("Device Connected to Server: $device");
    // Send a handshake to begin conversation
    //server.send(Packet.from(WordPair.random().asPascalCase), device);
    // Send file to Client
    server.send(Packet.fromStream(new File("sample.txt").openRead()), device);
  }

  @override
  void onDisconnected(Device device, bool isError, Object error, StackTrace stackTrace) {
    print("Device Disconnected from Server: $device");
  }

  @override
  void onMessage(Packet packet, Device device) {
    print("Message Received from Client $device: ${packet.asString()}");
    Future.delayed(Duration(seconds: 1)).then((_) =>
        server.send(Packet.from(WordPair.random().asPascalCase), device,
            ignoreIfNotConnected: true)
    );
  }
}