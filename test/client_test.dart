import 'dart:io';

import 'package:network_data_transfer/host.dart';
import 'package:english_words/english_words.dart';

Iterable<Device> devices;
Client client;
bool receivedFile = false;

void main() async{
  client = Client(
    ipVersion: IPVersion.v4,
    name: "Client",
    deviceDiscoveryListener: MyDiscoveryListener(),
    connectionListener: MyConnectionListener(),
  );

  if(!await client.ready){
    print("Could not start on Client");
    return;
  }
  print("Client is ready. IP: ${client.ipAddress}");

  // Start discovering devices
  print("Discovering hosts...");
  client.discoverHosts();
}

class MyDiscoveryListener implements DeviceDiscoveryListener{
  @override
  onDiscovery(Device newDevice, Iterable<Device> allDevices) {
    print("Server Discovery Alert: $newDevice");
    devices = allDevices;

    // Connect to Server
    client.connectTo(newDevice);
  }
  @override
  onClose(bool isError, Object error, StackTrace stackTrace){
    print("Discovery multicast socket closed");
  }

  @override
  void onAdvertisement(Device device, Packet packet) {
    print("Received ${packet.asString()} in onAdvertisement from Server.");
  }
}

class MyConnectionListener implements ConnectionListener{
  @override
  void onConnected(Device device) {
    print("Server Connected: $device");
  }

  @override
  void onDisconnected(Device device, bool isError, Object error, StackTrace stackTrace) {
    print("Server Disconnected: $device");
  }

  @override
  void onMessage(Packet packet, Device device) async {
    if( receivedFile )
      print("Message Received from Server $device: ${packet.asString()}");
    else{
      receivedFile = true;
      print("File [sample_copy.txt] Received from Server $device: ${packet.asString()}");
      await new File("sample_copy.txt").openWrite()..add(packet.bytes)..flush();
    }
    // Send message back to this client
    Future.delayed(Duration(seconds: 1)).then((_) =>
        client.send(Packet.from(WordPair.random().asPascalCase), device,
            ignoreIfNotConnected: true)
    );
  }
}