part of 'host.dart';

/// This class models the raw data that needs to be sent or received over the network.
/// and is just a wrapper around the raw bytes/stream.
///
/// Packets can serialize and deserialize formats supported by [jsonEncode] using
/// [Packet.from]. When using [Packet.from], it assumes that the enclosed data is
/// safe for utf8 encoding and decoding.
///
/// If you want to create a Packet from raw bytes, you have two options:
/// 1. If you already know all the bytes, you can use [Packet.fromBytes].
/// 2. If you don't yet have all of the bytes, you can use the Packet
///   constructor and keep adding bytes using the [add] or [addAll] methods
///
/// If you want to create a Packet from stream, use the [Packet.fromStream]
/// constructor.
class Packet{
  List<int> _bytes; // The raw bytes
  Stream<List<int>> _stream;
  bool _isStream;

  Packet(){
    _bytes = List<int>();
    _isStream = false;  // Default to false;
  }

  /// Allow Packets to be created from different data types. Supported data types are:
  /// String, numbers, Map, List, and Uint8List.
  /// Complex data types such as Map and List must be supported by jsonEncode
  factory Packet.from(dynamic data){
    Packet p = Packet();
    String content;
    if( data is Uint8List ){
      p._bytes = data.toList();
      return p;
    }
    else if( data is String )
      content = data;
    else if( data is Map || data is List )
      content = jsonEncode(data);
    else if( data is num )
      content = data.toString();
    else if( data is bool )
      content = "$data";
    else
      throw new Exception("Unsupported data type. Serialize to one of the supported formats");

    p._bytes = utf8.encode(content);
    return p;
  }

  /// Allow Packets to be created/copied from other bytes
  factory Packet.fromBytes(List<int> bytes){
    Packet p = Packet();
    p._bytes = bytes.sublist(0);
    return p;
  }

  /// Allow Packets to be created from Stream
  factory Packet.fromStream(Stream<List<int>> stream){
    Packet p = Packet();
    p._stream = stream;
    p._isStream = true;
    return p;
  }

  add(int byte){
    assert(_isStream != null && !_isStream);
    _bytes.add(byte);
  }

  addAll(Iterable<int> bytes){
    assert(_isStream != null && !_isStream);
    _bytes.addAll(bytes);
  }

  Uint8List get bytes{
    assert(_isStream != null && !_isStream);
    return Uint8List.fromList(_bytes);
  }

  bool get isStream => _isStream;

  Stream get stream{
    assert(_isStream != null && _isStream);
    return _stream;
  }

  int get size{
    assert(_isStream != null && !_isStream);
    return _bytes.length;
  }

  /// Allow transformation back to popular data types
  /// For using these methods, We're assuming it is safe to transform to String

  E as<E>(){
    assert(_isStream != null && !_isStream);

    if( E == String )
      return asString() as E;
    else if( E.toString() == Map<String, dynamic>().runtimeType.toString() )
      return asMap() as E;
    else if( E.toString() == List<dynamic>().runtimeType.toString() )
      return asList() as E;
    else if( E == int )
      return asInt() as E;
    else if( E == double )
      return asDouble() as E;
    else if( E == num )
      return asNumber() as E;
    else if( E == bool )
      return asBool() as E;

    throw new Exception("Unsupported return type. Deserialize to one of the supported formats");
  }

  String asString(){
    assert(_isStream != null && !_isStream);
    return utf8.decode(_bytes.toList());
  }

  Map<String, dynamic> asMap(){
    assert(_isStream != null && !_isStream);
    return jsonDecode(asString());
  }

  List<dynamic> asList(){
    assert(_isStream != null && !_isStream);
    return jsonDecode(asString());
  }

  num asNumber(){
    assert(_isStream != null && !_isStream);
    return num.parse(asString());
  }

  int asInt(){
    assert(_isStream != null && !_isStream);
    return int.parse(asString());
  }

  double asDouble(){
    assert(_isStream != null && !_isStream);
    return double.parse(asString());
  }

  bool asBool(){
    assert(_isStream != null && !_isStream);
    return asString() == "true";
  }
}