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

  /// Add a single by to this packet
  add(int byte){
    assert(_isStream != null && !_isStream);
    _bytes.add(byte);
  }

  /// Add bytes to this packet
  addAll(Iterable<int> bytes){
    assert(_isStream != null && !_isStream);
    _bytes.addAll(bytes);
  }

  /// Get the raw bytes in this packet
  Uint8List get bytes{
    assert(_isStream != null && !_isStream);
    return Uint8List.fromList(_bytes);
  }

  /// Check is this packet is enclosing a stream
  bool get isStream => _isStream;

  /// Get the enclosing stream
  Stream get stream{
    assert(_isStream != null && _isStream);
    return _stream;
  }

  /// Get the size of the bytes in this packet.
  /// This only works if the packet is not a stream.
  int get size{
    assert(_isStream != null && !_isStream);
    return _bytes.length;
  }

  /// Allow transformation back to popular data types
  /// For using the as() and asXX() methods, We're assuming it is safe to
  /// transform to utf8 Strings.
  ///
  /// This method provides a common generic way of transforming the bytes
  /// to one the supported serialization formats. As an example:
  /// as<String>() is same as asString()
  /// as<Map> is same as asMap()
  /// as<Map<String, dynamic>>() is same as asMap<String, dynamic>()
  /// as<List>() is same as asList()
  /// as<int>() is same as asInt()
  E as<E>(){
    assert(_isStream != null && !_isStream);

    if( E == String )
      return asString() as E;
    else if( E.toString().startsWith("Map<") )
      return asMap() as E;
    else if( E.toString().startsWith("List<") )
      return asList() as E;
    else if( E == int )
      return asInt() as E;
    else if( E == double )
      return asDouble() as E;
    else if( E == num )
      return asNumber() as E;
    else if( E == bool )
      return asBool() as E;

    throw "Unsupported return type. Deserialize to one of the supported formats";
  }

  /// For using this method, We're assuming it is safe to transform to utf8 Strings.
  /// Return the bytes as utf8 encoded string. Same as as<String>().
  String asString(){
    assert(_isStream != null && !_isStream);
    return utf8.decode(_bytes.toList());
  }

  /// For using this method, We're assuming it is safe to transform to utf8 Strings.
  /// Return the bytes as a Map decoded using jsonDecode(). Same as as<Map>().
  /// If the Key and Value are Strings, you can do asMap<String, String>() or get
  /// the dynamic form and do the cast yourself.
  Map<E, F> asMap<E, F>(){
    assert(_isStream != null && !_isStream);
    return jsonDecode(asString()) as Map<E, F>;
  }

  /// For using this method, We're assuming it is safe to transform to utf8 Strings.
  /// Return the bytes as a List decoded using jsonDecode(). Same as as<List>().
  /// If the List contains all String, you can do asList<String>() or get the dynamic form
  /// and do the cast yourself.
  List<E> asList<E>(){
    assert(_isStream != null && !_isStream);
    return jsonDecode(asString()) as List<E>;
  }

  /// For using this method, We're assuming it is safe to transform to utf8 Strings.
  /// Returns the bytes as a number using num.parse()
  num asNumber(){
    assert(_isStream != null && !_isStream);
    return num.parse(asString());
  }

  /// For using this method, We're assuming it is safe to transform to utf8 Strings.
  /// Returns the bytes as am integer using int.parse()
  int asInt(){
    assert(_isStream != null && !_isStream);
    return int.parse(asString());
  }

  /// For using this method, We're assuming it is safe to transform to utf8 Strings.
  /// Returns the bytes as a double using double.parse()
  double asDouble(){
    assert(_isStream != null && !_isStream);
    return double.parse(asString());
  }

  /// For using this method, We're assuming it is safe to transform to utf8 Strings.
  /// Returns the bytes as a boolean using string comparison
  bool asBool(){
    assert(_isStream != null && !_isStream);
    return asString() == "true";
  }
}