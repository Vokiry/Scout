namespace Soulseek.Protocol.Messages;

public interface IServerMessage
{
    int Code { get; }
    WriteBuffer Serialize();
}

public interface IPeerMessage
{
    int Code { get; }
    WriteBuffer Serialize();
}

public class LoginRequest : IServerMessage
{
    public string Username { get; }
    public string Password { get; }
    public int MinorVersion { get; }
    public int MajorVersion { get; }
    public int BuildVersion { get; }

    public LoginRequest(string username, string password, int minorVersion = 17, int majorVersion = 1, int buildVersion = 0)
    {
        Username = username;
        Password = password;
        MinorVersion = minorVersion;
        MajorVersion = majorVersion;
        BuildVersion = buildVersion;
    }

    public int Code => 1;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteString(Username);
        w.WriteString(Password);
        w.WriteInt32(MinorVersion);
        w.WriteInt32(MajorVersion);
        w.WriteInt32(BuildVersion);
        return w;
    }
}

public class LoginResponse
{
    public bool Success { get; }
    public int Ip { get; }
    public int Port { get; }
    public bool Obfuscated { get; }

    public LoginResponse(bool success, int ip, int port, bool obfuscated = false)
    {
        Success = success;
        Ip = ip;
        Port = port;
        Obfuscated = obfuscated;
    }

    public static LoginResponse Parse(ReadBuffer buffer)
    {
        var success = buffer.ReadInt32() == 1;
        var ip = buffer.ReadInt32();
        var port = buffer.ReadInt32();
        var obfuscated = buffer.Remaining >= 4 && buffer.ReadInt32() == 1;
        return new LoginResponse(success, ip, port, obfuscated);
    }
}

public class SetListenPort : IServerMessage
{
    public int Port { get; }

    public SetListenPort(int port)
    {
        Port = port;
    }

    public int Code => 2;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteInt32(Port);
        return w;
    }
}

public class GetPeerAddress : IServerMessage
{
    public string Username { get; }

    public GetPeerAddress(string username)
    {
        Username = username;
    }

    public int Code => 3;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteString(Username);
        return w;
    }
}

public class PeerAddressResponse
{
    public string Username { get; }
    public int Ip { get; }
    public int Port { get; }

    public PeerAddressResponse(string username, int ip, int port)
    {
        Username = username;
        Ip = ip;
        Port = port;
    }

    public static PeerAddressResponse Parse(ReadBuffer buffer)
    {
        var username = buffer.ReadString();
        var ip = buffer.ReadInt32();
        var port = buffer.ReadInt32();
        return new PeerAddressResponse(username, ip, port);
    }
}

public class AddUser : IServerMessage
{
    public string Username { get; }

    public AddUser(string username)
    {
        Username = username;
    }

    public int Code => 5;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteString(Username);
        return w;
    }
}

public class AddUserResponse
{
    public string Username { get; }
    public bool Exists { get; }
    public int Status { get; }

    public AddUserResponse(string username, bool exists, int status)
    {
        Username = username;
        Exists = exists;
        Status = status;
    }

    public static AddUserResponse Parse(ReadBuffer buffer)
    {
        var username = buffer.ReadString();
        var exists = buffer.ReadInt32() == 1;
        var status = buffer.ReadInt32();
        return new AddUserResponse(username, exists, status);
    }
}

public class UserStatusMessage
{
    public string Username { get; }
    public int Status { get; }

    public UserStatusMessage(string username, int status)
    {
        Username = username;
        Status = status;
    }

    public static UserStatusMessage Parse(ReadBuffer buffer)
    {
        var username = buffer.ReadString();
        var status = buffer.ReadInt32();
        return new UserStatusMessage(username, status);
    }
}

public class SearchRequest : IServerMessage
{
    public string Query { get; }
    public int Ticket { get; }

    public SearchRequest(string query, int ticket)
    {
        Query = query;
        Ticket = ticket;
    }

    public int Code => 26;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteInt32(Ticket);
        w.WriteString(Query);
        return w;
    }
}

public class SearchResultFile
{
    public int Code { get; }
    public string Filename { get; }
    public int Size { get; }
    public string Extension { get; }
    public int AttributeCount { get; }
    public int Bitrate { get; }
    public int Duration { get; }
    public int SampleRate { get; }
    public int? BitrateVbr { get; }

    public SearchResultFile(int code, string filename, int size, string extension, int attributeCount,
        int bitrate, int duration, int sampleRate, int? bitrateVbr = null)
    {
        Code = code;
        Filename = filename;
        Size = size;
        Extension = extension;
        AttributeCount = attributeCount;
        Bitrate = bitrate;
        Duration = duration;
        SampleRate = sampleRate;
        BitrateVbr = bitrateVbr;
    }

    public static SearchResultFile Parse(ReadBuffer buffer)
    {
        var code = buffer.ReadInt32();
        var filename = buffer.ReadString();
        var size = buffer.ReadInt32();
        var extension = buffer.ReadString();
        var attributeCount = buffer.ReadInt32();

        int bitrate = 0, duration = 0, sampleRate = 0;
        int? bitrateVbr = null;

        for (int i = 0; i < attributeCount; i++)
        {
            var attrType = buffer.ReadInt32();
            var attrValue = buffer.ReadInt32();
            switch (attrType)
            {
                case 0: bitrate = attrValue; break;
                case 1: duration = attrValue; break;
                case 2: sampleRate = attrValue; break;
                case 3: bitrateVbr = attrValue; break;
            }
        }

        return new SearchResultFile(code, filename, size, extension, attributeCount, bitrate, duration, sampleRate, bitrateVbr);
    }

    public static SearchResultFile ParseOld(ReadBuffer buffer)
    {
        var code = buffer.ReadInt32();
        var filename = buffer.ReadString();
        var size = buffer.ReadInt32();
        var extension = buffer.ReadString();
        var attributeCount = buffer.ReadInt32();

        int bitrate = 0, duration = 0, sampleRate = 0;

        for (int i = 0; i < attributeCount; i++)
        {
            var attrType = buffer.ReadInt32();
            var attrValue = buffer.ReadInt32();
            switch (attrType)
            {
                case 0: bitrate = attrValue; break;
                case 1: duration = attrValue; break;
                case 2: sampleRate = attrValue; break;
            }
        }

        return new SearchResultFile(code, filename, size, extension, attributeCount, bitrate, duration, sampleRate);
    }
}

public class SearchResponseData
{
    public string Username { get; }
    public int Ticket { get; }
    public int TotalFileCount { get; }
    public int FreeUploadSlots { get; }
    public int UploadSpeed { get; }
    public int QueueLength { get; }
    public List<SearchResultFile> Files { get; }

    public SearchResponseData(string username, int ticket, int totalFileCount, int freeUploadSlots,
        int uploadSpeed, int queueLength, List<SearchResultFile> files)
    {
        Username = username;
        Ticket = ticket;
        TotalFileCount = totalFileCount;
        FreeUploadSlots = freeUploadSlots;
        UploadSpeed = uploadSpeed;
        QueueLength = queueLength;
        Files = files;
    }

    public static SearchResponseData Parse(ReadBuffer buffer)
    {
        var username = buffer.ReadString();
        var ticket = buffer.ReadInt32();
        var totalFileCount = buffer.ReadInt32();
        var freeUploadSlots = buffer.ReadInt32();
        var uploadSpeed = buffer.ReadInt32();
        var queueLength = buffer.ReadInt32();
        var fileCount = buffer.ReadInt32();

        var files = new List<SearchResultFile>();
        for (int i = 0; i < fileCount; i++)
        {
            files.Add(SearchResultFile.Parse(buffer));
        }

        return new SearchResponseData(username, ticket, totalFileCount, freeUploadSlots, uploadSpeed, queueLength, files);
    }

    public static SearchResponseData ParseOld(ReadBuffer buffer)
    {
        var username = buffer.ReadString();
        var ticket = buffer.ReadInt32();
        var fileCount = buffer.ReadInt32();

        var files = new List<SearchResultFile>();
        for (int i = 0; i < fileCount; i++)
        {
            files.Add(SearchResultFile.ParseOld(buffer));
        }

        var freeUploadSlots = buffer.Remaining >= 4 ? buffer.ReadInt32() : 0;
        var uploadSpeed = buffer.Remaining >= 4 ? buffer.ReadInt32() : 0;
        var queueLength = buffer.Remaining >= 4 ? buffer.ReadInt32() : 0;

        return new SearchResponseData(username, ticket, fileCount, freeUploadSlots, uploadSpeed, queueLength, files);
    }
}

public class PrivateMessage : IServerMessage
{
    public string Username { get; }
    public string Message { get; }
    public int Timestamp { get; }

    public PrivateMessage(string username, string message, int timestamp)
    {
        Username = username;
        Message = message;
        Timestamp = timestamp;
    }

    public int Code => 51;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteString(Username);
        w.WriteString(Message);
        return w;
    }

    public static PrivateMessage Parse(ReadBuffer buffer)
    {
        var username = buffer.ReadString();
        var message = buffer.ReadString();
        var timestamp = buffer.ReadInt32();
        return new PrivateMessage(username, message, timestamp);
    }
}

public class Ping : IServerMessage
{
    public int Code => 40;
    public WriteBuffer Serialize() => new();
}

public class CheckDownloadQueue : IServerMessage
{
    public List<string> Usernames { get; }

    public CheckDownloadQueue(List<string> usernames)
    {
        Usernames = usernames;
    }

    public int Code => 58;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteInt32(Usernames.Count);
        foreach (var u in Usernames)
            w.WriteString(u);
        return w;
    }
}

public class FolderContentsRequest : IPeerMessage
{
    public string Directory { get; }

    public FolderContentsRequest(string directory)
    {
        Directory = directory;
    }

    public int Code => 131;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteString(Directory);
        return w;
    }
}

public class SharedFile
{
    public int Code { get; }
    public string Filename { get; }
    public long Size { get; }
    public string Extension { get; }
    public int AttributeCount { get; }
    public int Bitrate { get; }
    public int Duration { get; }
    public int SampleRate { get; }
    public int? BitrateVbr { get; }

    public SharedFile(int code, string filename, long size, string extension, int attributeCount,
        int bitrate, int duration, int sampleRate, int? bitrateVbr = null)
    {
        Code = code;
        Filename = filename;
        Size = size;
        Extension = extension;
        AttributeCount = attributeCount;
        Bitrate = bitrate;
        Duration = duration;
        SampleRate = sampleRate;
        BitrateVbr = bitrateVbr;
    }

    public static SharedFile Parse(ReadBuffer buffer)
    {
        var code = buffer.ReadInt32();
        var filename = buffer.ReadString();
        var size = (long)buffer.ReadUint64();
        var extension = buffer.ReadString();
        var attributeCount = buffer.ReadInt32();

        int bitrate = 0, duration = 0, sampleRate = 0;
        int? bitrateVbr = null;

        for (int i = 0; i < attributeCount; i++)
        {
            var attrType = buffer.ReadInt32();
            var attrValue = buffer.ReadInt32();
            switch (attrType)
            {
                case 0: bitrate = attrValue; break;
                case 1: duration = attrValue; break;
                case 2: sampleRate = attrValue; break;
                case 3: bitrateVbr = attrValue; break;
            }
        }

        return new SharedFile(code, filename, size, extension, attributeCount, bitrate, duration, sampleRate, bitrateVbr);
    }
}

public class SharedFolder
{
    public string Path { get; }
    public List<SharedFile> Files { get; }

    public SharedFolder(string path, List<SharedFile> files)
    {
        Path = path;
        Files = files;
    }

    public static SharedFolder Parse(ReadBuffer buffer)
    {
        var path = buffer.ReadString();
        var fileCount = buffer.ReadInt32();
        var files = new List<SharedFile>();
        for (int i = 0; i < fileCount; i++)
            files.Add(SharedFile.Parse(buffer));
        return new SharedFolder(path, files);
    }
}

public class FolderContentsReply
{
    public List<SharedFolder> Folders { get; }

    public FolderContentsReply(List<SharedFolder> folders)
    {
        Folders = folders;
    }

    public static FolderContentsReply Parse(ReadBuffer buffer)
    {
        var folderCount = buffer.ReadInt32();
        var folders = new List<SharedFolder>();
        for (int i = 0; i < folderCount; i++)
            folders.Add(SharedFolder.Parse(buffer));
        return new FolderContentsReply(folders);
    }
}

public class TransferRequest : IPeerMessage
{
    public int Direction { get; }
    public int FileCode { get; }
    public string Filename { get; }
    public int FileSize { get; }

    public TransferRequest(int direction, int fileCode, string filename, int fileSize)
    {
        Direction = direction;
        FileCode = fileCode;
        Filename = filename;
        FileSize = fileSize;
    }

    public int Code => 135;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteInt32(Direction);
        w.WriteInt32(FileCode);
        w.WriteString(Filename);
        w.WriteInt32(FileSize);
        return w;
    }
}

public class WishlistSearchRequest : IServerMessage
{
    public int Ticket { get; }
    public string Query { get; }

    public WishlistSearchRequest(int ticket, string query)
    {
        Ticket = ticket;
        Query = query;
    }

    public int Code => 67;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteInt32(Ticket);
        w.WriteString(Query);
        return w;
    }
}

public class WishlistInclusion : IServerMessage
{
    public bool Add { get; }
    public string Phrase { get; }

    public WishlistInclusion(bool add, string phrase)
    {
        Add = add;
        Phrase = phrase;
    }

    public int Code => 69;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteInt32(Add ? 1 : 0);
        w.WriteString(Phrase);
        return w;
    }
}

public class WishlistReply
{
    public string Username { get; }
    public int Ticket { get; }
    public int FreeUploadSlots { get; }
    public int UploadSpeed { get; }
    public int QueueLength { get; }
    public List<SearchResultFile> Files { get; }

    public WishlistReply(string username, int ticket, int freeUploadSlots, int uploadSpeed, int queueLength, List<SearchResultFile> files)
    {
        Username = username;
        Ticket = ticket;
        FreeUploadSlots = freeUploadSlots;
        UploadSpeed = uploadSpeed;
        QueueLength = queueLength;
        Files = files;
    }

    public static WishlistReply Parse(ReadBuffer buffer)
    {
        var username = buffer.ReadString();
        var ticket = buffer.ReadInt32();
        var freeUploadSlots = buffer.ReadInt32();
        var uploadSpeed = buffer.ReadInt32();
        var queueLength = buffer.ReadInt32();
        var fileCount = buffer.ReadInt32();

        var files = new List<SearchResultFile>();
        for (int i = 0; i < fileCount; i++)
            files.Add(SearchResultFile.Parse(buffer));

        return new WishlistReply(username, ticket, freeUploadSlots, uploadSpeed, queueLength, files);
    }
}

public class JoinRoom : IServerMessage
{
    public string RoomName { get; }

    public JoinRoom(string roomName)
    {
        RoomName = roomName;
    }

    public int Code => 43;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteString(RoomName);
        return w;
    }
}

public class LeaveRoom : IServerMessage
{
    public string RoomName { get; }

    public LeaveRoom(string roomName)
    {
        RoomName = roomName;
    }

    public int Code => 44;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteString(RoomName);
        return w;
    }
}

public class RoomMessageData
{
    public string RoomName { get; }
    public string Username { get; }
    public string Message { get; }

    public RoomMessageData(string roomName, string username, string message)
    {
        RoomName = roomName;
        Username = username;
        Message = message;
    }

    public static RoomMessageData Parse(ReadBuffer buffer)
    {
        var roomName = buffer.ReadString();
        var username = buffer.ReadString();
        var message = buffer.ReadString();
        return new RoomMessageData(roomName, username, message);
    }
}

public class SendRoomMessage : IServerMessage
{
    public string RoomName { get; }
    public string Message { get; }

    public SendRoomMessage(string roomName, string message)
    {
        RoomName = roomName;
        Message = message;
    }

    public int Code => 47;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteString(RoomName);
        w.WriteString(Message);
        return w;
    }
}

public class UserJoinedRoom
{
    public string RoomName { get; }
    public string Username { get; }
    public int FreeUploadSlots { get; }
    public int UploadSpeed { get; }
    public int FilesCount { get; }
    public int DirectoryCount { get; }

    public UserJoinedRoom(string roomName, string username, int freeUploadSlots = 0,
        int uploadSpeed = 0, int filesCount = 0, int directoryCount = 0)
    {
        RoomName = roomName;
        Username = username;
        FreeUploadSlots = freeUploadSlots;
        UploadSpeed = uploadSpeed;
        FilesCount = filesCount;
        DirectoryCount = directoryCount;
    }

    public static UserJoinedRoom Parse(ReadBuffer buffer)
    {
        var roomName = buffer.ReadString();
        var username = buffer.ReadString();
        var freeUploadSlots = buffer.Remaining >= 4 ? buffer.ReadInt32() : 0;
        var uploadSpeed = buffer.Remaining >= 4 ? buffer.ReadInt32() : 0;
        var filesCount = buffer.Remaining >= 4 ? buffer.ReadInt32() : 0;
        var directoryCount = buffer.Remaining >= 4 ? buffer.ReadInt32() : 0;
        return new UserJoinedRoom(roomName, username, freeUploadSlots, uploadSpeed, filesCount, directoryCount);
    }
}

public class UserLeftRoom
{
    public string RoomName { get; }
    public string Username { get; }

    public UserLeftRoom(string roomName, string username)
    {
        RoomName = roomName;
        Username = username;
    }

    public static UserLeftRoom Parse(ReadBuffer buffer)
    {
        var roomName = buffer.ReadString();
        var username = buffer.ReadString();
        return new UserLeftRoom(roomName, username);
    }
}

public class RoomListEntry
{
    public string Name { get; }
    public int UserCount { get; }

    public RoomListEntry(string name, int userCount)
    {
        Name = name;
        UserCount = userCount;
    }
}

public class RoomList
{
    public List<RoomListEntry> Rooms { get; }

    public RoomList(List<RoomListEntry> rooms)
    {
        Rooms = rooms;
    }

    public static RoomList Parse(ReadBuffer buffer)
    {
        var count = buffer.ReadInt32();
        var rooms = new List<RoomListEntry>();
        for (int i = 0; i < count; i++)
        {
            var name = buffer.ReadString();
            var userCount = buffer.ReadInt32();
            rooms.Add(new RoomListEntry(name, userCount));
        }
        return new RoomList(rooms);
    }
}

public class PrivateRoomUsers : IServerMessage
{
    public string RoomName { get; }

    public PrivateRoomUsers(string roomName)
    {
        RoomName = roomName;
    }

    public int Code => 135;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteString(RoomName);
        return w;
    }
}

public class RoomTickerSet : IServerMessage
{
    public string RoomName { get; }
    public string Ticker { get; }

    public RoomTickerSet(string roomName, string ticker)
    {
        RoomName = roomName;
        Ticker = ticker;
    }

    public int Code => 150;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteString(RoomName);
        w.WriteString(Ticker);
        return w;
    }
}

public class RoomTickerRemove : IServerMessage
{
    public string RoomName { get; }

    public RoomTickerRemove(string roomName)
    {
        RoomName = roomName;
    }

    public int Code => 151;

    public WriteBuffer Serialize()
    {
        var w = new WriteBuffer();
        w.WriteString(RoomName);
        return w;
    }
}

public class UserInfoRequest : IPeerMessage
{
    public int Code => 133;
    public WriteBuffer Serialize() => new();
}