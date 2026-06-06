import 'buffer.dart';

abstract class ServerMessage {
  int get code;
  WriteBuffer serialize();
}

abstract class PeerMessage {
  int get code;
  WriteBuffer serialize();
}

class LoginRequest implements ServerMessage {
  final String username;
  final String password;
  final int minorVersion;
  final int majorVersion;
  final int buildVersion;

  LoginRequest({
    required this.username,
    required this.password,
    this.minorVersion = 17,
    this.majorVersion = 1,
    this.buildVersion = 0,
  });

  @override
  int get code => 1;

  @override
  WriteBuffer serialize() {
    final w = WriteBuffer();
    w.writeString(username);
    w.writeString(password);
    w.writeInt32(minorVersion);
    w.writeInt32(majorVersion);
    w.writeInt32(buildVersion);
    return w;
  }
}

class LoginResponse {
  final bool success;
  final int ip;
  final int port;
  final bool obfuscated;

  LoginResponse({
    required this.success,
    required this.ip,
    required this.port,
    required this.obfuscated,
  });

  static LoginResponse parse(ReadBuffer buffer) {
    final success = buffer.readInt32() == 1;
    final ip = buffer.readInt32();
    final port = buffer.readInt32();
    final obfuscated = buffer.remaining >= 4 && buffer.readInt32() == 1;
    return LoginResponse(success: success, ip: ip, port: port, obfuscated: obfuscated);
  }
}

class SetListenPort implements ServerMessage {
  final int port;

  SetListenPort(this.port);

  @override
  int get code => 2;

  @override
  WriteBuffer serialize() {
    final w = WriteBuffer();
    w.writeInt32(port);
    return w;
  }
}

class GetPeerAddress implements ServerMessage {
  final String username;

  GetPeerAddress(this.username);

  @override
  int get code => 3;

  @override
  WriteBuffer serialize() {
    final w = WriteBuffer();
    w.writeString(username);
    return w;
  }
}

class PeerAddressResponse {
  final String username;
  final int ip;
  final int port;

  PeerAddressResponse({
    required this.username,
    required this.ip,
    required this.port,
  });

  static PeerAddressResponse parse(ReadBuffer buffer) {
    final username = buffer.readString();
    final ip = buffer.readInt32();
    final port = buffer.readInt32();
    return PeerAddressResponse(username: username, ip: ip, port: port);
  }
}

class AddUser implements ServerMessage {
  final String username;

  AddUser(this.username);

  @override
  int get code => 5;

  @override
  WriteBuffer serialize() {
    final w = WriteBuffer();
    w.writeString(username);
    return w;
  }
}

class AddUserResponse {
  final String username;
  final bool exists;
  final int status;

  AddUserResponse({
    required this.username,
    required this.exists,
    required this.status,
  });

  static AddUserResponse parse(ReadBuffer buffer) {
    final username = buffer.readString();
    final exists = buffer.readInt32() == 1;
    final status = buffer.readInt32();
    return AddUserResponse(username: username, exists: exists, status: status);
  }
}

class UserStatus {
  final String username;
  final int status;

  UserStatus({required this.username, required this.status});

  static UserStatus parse(ReadBuffer buffer) {
    final username = buffer.readString();
    final status = buffer.readInt32();
    return UserStatus(username: username, status: status);
  }
}

class SearchRequest implements ServerMessage {
  final String query;
  final int ticket;

  SearchRequest({required this.query, required this.ticket});

  @override
  int get code => 26;

  @override
  WriteBuffer serialize() {
    final w = WriteBuffer();
    w.writeInt32(ticket);
    w.writeString(query);
    return w;
  }
}

class SearchResponseData {
  final String username;
  final int ticket;
  final int totalFileCount;
  final int freeUploadSlots;
  final int uploadSpeed;
  final int queueLength;
  final List<SearchResultFile> files;

  SearchResponseData({
    required this.username,
    required this.ticket,
    required this.totalFileCount,
    required this.freeUploadSlots,
    required this.uploadSpeed,
    required this.queueLength,
    required this.files,
  });

  static SearchResponseData parse(ReadBuffer buffer) {
    final username = buffer.readString();
    final ticket = buffer.readInt32();
    final totalFileCount = buffer.readInt32();
    final freeUploadSlots = buffer.readInt32();
    final uploadSpeed = buffer.readInt32();
    final queueLength = buffer.readInt32();
    final fileCount = buffer.readInt32();

    final files = <SearchResultFile>[];
    for (int i = 0; i < fileCount; i++) {
      files.add(SearchResultFile.parse(buffer));
    }

    return SearchResponseData(
      username: username,
      ticket: ticket,
      totalFileCount: totalFileCount,
      freeUploadSlots: freeUploadSlots,
      uploadSpeed: uploadSpeed,
      queueLength: queueLength,
      files: files,
    );
  }

  static SearchResponseData parseOld(ReadBuffer buffer) {
    final username = buffer.readString();
    final ticket = buffer.readInt32();
    final fileCount = buffer.readInt32();

    final files = <SearchResultFile>[];
    for (int i = 0; i < fileCount; i++) {
      files.add(SearchResultFile.parseOld(buffer));
    }

    final freeUploadSlots = buffer.remaining >= 4 ? buffer.readInt32() : 0;
    final uploadSpeed = buffer.remaining >= 4 ? buffer.readInt32() : 0;
    final queueLength = buffer.remaining >= 4 ? buffer.readInt32() : 0;

    return SearchResponseData(
      username: username,
      ticket: ticket,
      totalFileCount: fileCount,
      freeUploadSlots: freeUploadSlots,
      uploadSpeed: uploadSpeed,
      queueLength: queueLength,
      files: files,
    );
  }
}

class SearchResultFile {
  final int code;
  final String filename;
  final int size;
  final String extension;
  final int attributeCount;
  final int bitrate;
  final int duration;
  final int sampleRate;
  final int? bitrateVbr;

  SearchResultFile({
    required this.code,
    required this.filename,
    required this.size,
    required this.extension,
    required this.attributeCount,
    required this.bitrate,
    required this.duration,
    required this.sampleRate,
    this.bitrateVbr,
  });

  static SearchResultFile parse(ReadBuffer buffer) {
    final code = buffer.readInt32();
    final filename = buffer.readString();
    final size = buffer.readInt32();
    final extension = buffer.readString();
    final attributeCount = buffer.readInt32();

    int bitrate = 0;
    int duration = 0;
    int sampleRate = 0;
    int? bitrateVbr;

    for (int i = 0; i < attributeCount; i++) {
      final attrType = buffer.readInt32();
      final attrValue = buffer.readInt32();
      switch (attrType) {
        case 0:
          bitrate = attrValue;
          break;
        case 1:
          duration = attrValue;
          break;
        case 2:
          sampleRate = attrValue;
          break;
        case 3:
          bitrateVbr = attrValue;
          break;
      }
    }

    return SearchResultFile(
      code: code,
      filename: filename,
      size: size,
      extension: extension,
      attributeCount: attributeCount,
      bitrate: bitrate,
      duration: duration,
      sampleRate: sampleRate,
      bitrateVbr: bitrateVbr,
    );
  }

  static SearchResultFile parseOld(ReadBuffer buffer) {
    final code = buffer.readInt32();
    final filename = buffer.readString();
    final size = buffer.readInt32();
    final extension = buffer.readString();
    final attributeCount = buffer.readInt32();

    int bitrate = 0;
    int duration = 0;
    int sampleRate = 0;

    for (int i = 0; i < attributeCount; i++) {
      final attrType = buffer.readInt32();
      final attrValue = buffer.readInt32();
      switch (attrType) {
        case 0:
          bitrate = attrValue;
          break;
        case 1:
          duration = attrValue;
          break;
        case 2:
          sampleRate = attrValue;
          break;
      }
    }

    return SearchResultFile(
      code: code,
      filename: filename,
      size: size,
      extension: extension,
      attributeCount: attributeCount,
      bitrate: bitrate,
      duration: duration,
      sampleRate: sampleRate,
    );
  }
}

class PrivateMessage implements ServerMessage {
  final String username;
  final String message;
  final int timestamp;

  PrivateMessage({
    required this.username,
    required this.message,
    required this.timestamp,
  });

  @override
  int get code => 51;

  @override
  WriteBuffer serialize() {
    final w = WriteBuffer();
    w.writeString(username);
    w.writeString(message);
    return w;
  }

  static PrivateMessage parse(ReadBuffer buffer) {
    final username = buffer.readString();
    final message = buffer.readString();
    final timestamp = buffer.readInt32();
    return PrivateMessage(username: username, message: message, timestamp: timestamp);
  }
}

class Ping implements ServerMessage {
  @override
  int get code => 40;

  @override
  WriteBuffer serialize() => WriteBuffer();
}

class CheckDownloadQueue implements ServerMessage {
  final List<String> usernames;

  CheckDownloadQueue(this.usernames);

  @override
  int get code => 58;

  @override
  WriteBuffer serialize() {
    final w = WriteBuffer();
    w.writeInt32(usernames.length);
    for (final u in usernames) {
      w.writeString(u);
    }
    return w;
  }
}

class FolderContentsRequest implements PeerMessage {
  final String directory;

  FolderContentsRequest(this.directory);

  @override
  int get code => 131;

  @override
  WriteBuffer serialize() {
    final w = WriteBuffer();
    w.writeString(directory);
    return w;
  }
}

class UserInfoRequest implements PeerMessage {
  @override
  int get code => 133;

  @override
  WriteBuffer serialize() => WriteBuffer();
}

class SharedFile {
  final int code;
  final String filename;
  final int size;
  final String extension;
  final int attributeCount;
  final int bitrate;
  final int duration;
  final int sampleRate;
  final int? bitrateVbr;

  SharedFile({
    required this.code,
    required this.filename,
    required this.size,
    required this.extension,
    required this.attributeCount,
    required this.bitrate,
    required this.duration,
    required this.sampleRate,
    this.bitrateVbr,
  });

  static SharedFile parse(ReadBuffer buffer) {
    final code = buffer.readInt32();
    final filename = buffer.readString();
    final size = buffer.readUint64();
    final extension = buffer.readString();
    final attributeCount = buffer.readInt32();

    int bitrate = 0;
    int duration = 0;
    int sampleRate = 0;
    int? bitrateVbr;

    for (int i = 0; i < attributeCount; i++) {
      final attrType = buffer.readInt32();
      final attrValue = buffer.readInt32();
      switch (attrType) {
        case 0:
          bitrate = attrValue;
          break;
        case 1:
          duration = attrValue;
          break;
        case 2:
          sampleRate = attrValue;
          break;
        case 3:
          bitrateVbr = attrValue;
          break;
      }
    }

    return SharedFile(
      code: code,
      filename: filename,
      size: size,
      extension: extension,
      attributeCount: attributeCount,
      bitrate: bitrate,
      duration: duration,
      sampleRate: sampleRate,
      bitrateVbr: bitrateVbr,
    );
  }
}

class SharedFolder {
  final String path;
  final List<SharedFile> files;

  SharedFolder({required this.path, required this.files});

  static SharedFolder parse(ReadBuffer buffer) {
    final path = buffer.readString();
    final fileCount = buffer.readInt32();
    final files = <SharedFile>[];
    for (int i = 0; i < fileCount; i++) {
      files.add(SharedFile.parse(buffer));
    }
    return SharedFolder(path: path, files: files);
  }
}

class FolderContentsReply {
  final List<SharedFolder> folders;

  FolderContentsReply(this.folders);

  static FolderContentsReply parse(ReadBuffer buffer) {
    final folderCount = buffer.readInt32();
    final folders = <SharedFolder>[];
    for (int i = 0; i < folderCount; i++) {
      folders.add(SharedFolder.parse(buffer));
    }
    return FolderContentsReply(folders);
  }
}

class TransferRequest implements PeerMessage {
  final int direction;
  final int fileCode;
  final String filename;
  final int fileSize;

  TransferRequest({
    required this.direction,
    required this.fileCode,
    required this.filename,
    required this.fileSize,
  });

  @override
  int get code => 135;

  @override
  WriteBuffer serialize() {
    final w = WriteBuffer();
    w.writeInt32(direction);
    w.writeInt32(fileCode);
    w.writeString(filename);
    w.writeInt32(fileSize);
    return w;
  }
}

class WishlistSearchRequest implements ServerMessage {
  final int ticket;
  final String query;

  WishlistSearchRequest({required this.ticket, required this.query});

  @override
  int get code => 67;

  @override
  WriteBuffer serialize() {
    final w = WriteBuffer();
    w.writeInt32(ticket);
    w.writeString(query);
    return w;
  }
}

class WishlistInclusion implements ServerMessage {
  final bool add;
  final String phrase;

  WishlistInclusion({required this.add, required this.phrase});

  @override
  int get code => 69;

  @override
  WriteBuffer serialize() {
    final w = WriteBuffer();
    w.writeInt32(add ? 1 : 0);
    w.writeString(phrase);
    return w;
  }
}

class WishlistReply {
  final String username;
  final int ticket;
  final int freeUploadSlots;
  final int uploadSpeed;
  final int queueLength;
  final List<SearchResultFile> files;

  WishlistReply({
    required this.username,
    required this.ticket,
    required this.freeUploadSlots,
    required this.uploadSpeed,
    required this.queueLength,
    required this.files,
  });

  static WishlistReply parse(ReadBuffer buffer) {
    final username = buffer.readString();
    final ticket = buffer.readInt32();
    final freeUploadSlots = buffer.readInt32();
    final uploadSpeed = buffer.readInt32();
    final queueLength = buffer.readInt32();
    final fileCount = buffer.readInt32();

    final files = <SearchResultFile>[];
    for (int i = 0; i < fileCount; i++) {
      files.add(SearchResultFile.parse(buffer));
    }

    return WishlistReply(
      username: username,
      ticket: ticket,
      freeUploadSlots: freeUploadSlots,
      uploadSpeed: uploadSpeed,
      queueLength: queueLength,
      files: files,
    );
  }
}
