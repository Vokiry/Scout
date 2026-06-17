using Xunit;
using Soulseek.Protocol.Messages;

namespace Soulseek.Protocol.Tests.Messages;

public class MessageClassTests
{
    [Fact]
    public void LoginRequest_SerializesCorrectly()
    {
        var req = new LoginRequest("testuser", "testpass");
        var w = req.Serialize();
        var bytes = w.ToBytes();
        var r = new ReadBuffer(bytes);

        Assert.Equal("testuser", r.ReadString());
        Assert.Equal("testpass", r.ReadString());
        Assert.Equal(17, r.ReadInt32());
        Assert.Equal(1, r.ReadInt32());
        Assert.Equal(0, r.ReadInt32());
    }

    [Fact]
    public void LoginResponse_Parse_Success()
    {
        var w = new WriteBuffer();
        w.WriteInt32(1);
        w.WriteInt32(0x7F000001);
        w.WriteInt32(2244);
        w.WriteInt32(0);

        var response = LoginResponse.Parse(new ReadBuffer(w.ToBytes()));
        Assert.True(response.Success);
        Assert.Equal(0x7F000001, response.Ip);
        Assert.Equal(2244, response.Port);
        Assert.False(response.Obfuscated);
    }

    [Fact]
    public void LoginResponse_Parse_Failure()
    {
        var w = new WriteBuffer();
        w.WriteInt32(0);
        w.WriteInt32(0);
        w.WriteInt32(0);

        var response = LoginResponse.Parse(new ReadBuffer(w.ToBytes()));
        Assert.False(response.Success);
    }

    [Fact]
    public void LoginResponse_Parse_Obfuscated()
    {
        var w = new WriteBuffer();
        w.WriteInt32(1);
        w.WriteInt32(0);
        w.WriteInt32(2234);
        w.WriteInt32(1);

        var response = LoginResponse.Parse(new ReadBuffer(w.ToBytes()));
        Assert.True(response.Obfuscated);
    }

    [Fact]
    public void SetListenPort_SerializesCorrectly()
    {
        var msg = new SetListenPort(2234);
        var bytes = msg.Serialize().ToBytes();
        Assert.Equal(2234, BitConverter.ToInt32(bytes));
    }

    [Fact]
    public void SearchRequest_SerializesCorrectly()
    {
        var msg = new SearchRequest("test query", 42);
        var bytes = msg.Serialize().ToBytes();
        var r = new ReadBuffer(bytes);
        Assert.Equal(42, r.ReadInt32());
        Assert.Equal("test query", r.ReadString());
    }

    [Fact]
    public void PrivateMessage_SerializesCorrectly()
    {
        var msg = new PrivateMessage("user1", "hello", 12345);
        var bytes = msg.Serialize().ToBytes();
        var r = new ReadBuffer(bytes);
        Assert.Equal("user1", r.ReadString());
        Assert.Equal("hello", r.ReadString());
    }

    [Fact]
    public void PrivateMessage_Parse_RoundTrip()
    {
        var original = new PrivateMessage("alice", "hi there", 98765);
        var bytes = original.Serialize().ToBytes();
        var parsed = PrivateMessage.Parse(new ReadBuffer(bytes));
        Assert.Equal(original.Username, parsed.Username);
        Assert.Equal(original.Message, parsed.Message);
        Assert.Equal(original.Timestamp, parsed.Timestamp);
    }

    [Fact]
    public void Ping_SerializesToEmpty()
    {
        var ping = new Ping();
        Assert.Empty(ping.Serialize().ToBytes());
        Assert.Equal(40, ping.Code);
    }

    [Fact]
    public void SearchResultFile_Parse_WithAttributes()
    {
        var w = new WriteBuffer();
        w.WriteInt32(1);
        w.WriteString("file.mp3");
        w.WriteInt32(5000000);
        w.WriteString("mp3");
        w.WriteInt32(3);
        w.WriteInt32(0); w.WriteInt32(320);
        w.WriteInt32(1); w.WriteInt32(300);
        w.WriteInt32(2); w.WriteInt32(44100);

        var file = SearchResultFile.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Equal(1, file.Code);
        Assert.Equal("file.mp3", file.Filename);
        Assert.Equal(5000000, file.Size);
        Assert.Equal("mp3", file.Extension);
        Assert.Equal(320, file.Bitrate);
        Assert.Equal(300, file.Duration);
        Assert.Equal(44100, file.SampleRate);
        Assert.Null(file.BitrateVbr);
    }

    [Fact]
    public void SearchResultFile_Parse_WithVbrAttribute()
    {
        var w = new WriteBuffer();
        w.WriteInt32(0);
        w.WriteString("song.flac");
        w.WriteInt32(10000000);
        w.WriteString("flac");
        w.WriteInt32(4);
        w.WriteInt32(0); w.WriteInt32(1000);
        w.WriteInt32(1); w.WriteInt32(240);
        w.WriteInt32(2); w.WriteInt32(96000);
        w.WriteInt32(3); w.WriteInt32(900);

        var file = SearchResultFile.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Equal(900, file.BitrateVbr);
    }

    [Fact]
    public void SearchResultFile_ParseOld_NoOptionalFields()
    {
        var w = new WriteBuffer();
        w.WriteInt32(1);
        w.WriteString("a.txt");
        w.WriteInt32(100);
        w.WriteString("txt");
        w.WriteInt32(0);

        var file = SearchResultFile.ParseOld(new ReadBuffer(w.ToBytes()));
        Assert.Equal(1, file.Code);
        Assert.Equal("a.txt", file.Filename);
        Assert.Equal(0, file.Bitrate);
    }

    [Fact]
    public void SearchResponseData_Parse_FullFormat()
    {
        var w = new WriteBuffer();
        w.WriteString("user1");
        w.WriteInt32(100);
        w.WriteInt32(5);
        w.WriteInt32(2);
        w.WriteInt32(100000);
        w.WriteInt32(0);
        w.WriteInt32(1);

        w.WriteInt32(1);
        w.WriteString("f1.mp3");
        w.WriteInt32(1000);
        w.WriteString("mp3");
        w.WriteInt32(2);
        w.WriteInt32(0); w.WriteInt32(256);
        w.WriteInt32(1); w.WriteInt32(180);

        var response = SearchResponseData.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Equal("user1", response.Username);
        Assert.Equal(100, response.Ticket);
        Assert.Equal(5, response.TotalFileCount);
        Assert.Equal(2, response.FreeUploadSlots);
        Assert.Equal(100000, response.UploadSpeed);
        Assert.Equal(0, response.QueueLength);
        Assert.Single(response.Files);
    }

    [Fact]
    public void SearchResponseData_ParseOld_FallsBack()
    {
        var w = new WriteBuffer();
        w.WriteString("olduser");
        w.WriteInt32(50);
        w.WriteInt32(1);
        w.WriteInt32(6);
        w.WriteString("old.txt");
        w.WriteInt32(200);
        w.WriteString("txt");
        w.WriteInt32(0);

        var response = SearchResponseData.ParseOld(new ReadBuffer(w.ToBytes()));
        Assert.Equal("olduser", response.Username);
        Assert.Equal(50, response.Ticket);
        Assert.Single(response.Files);
    }

    [Fact]
    public void UserStatusMessage_Parse()
    {
        var w = new WriteBuffer();
        w.WriteString("user1");
        w.WriteInt32(1);
        var status = UserStatusMessage.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Equal("user1", status.Username);
        Assert.Equal(1, status.Status);
    }

    [Fact]
    public void TransferRequest_SerializesCorrectly()
    {
        var req = new TransferRequest(Direction.Download, 5, "file.mp3", 1000000);
        var bytes = req.Serialize().ToBytes();
        var r = new ReadBuffer(bytes);
        Assert.Equal(Direction.Download, r.ReadInt32());
        Assert.Equal(5, r.ReadInt32());
        Assert.Equal("file.mp3", r.ReadString());
        Assert.Equal(1000000, r.ReadInt32());
    }

    [Fact]
    public void FolderContentsRequest_SerializesCorrectly()
    {
        var req = new FolderContentsRequest("\\music");
        var bytes = req.Serialize().ToBytes();
        var r = new ReadBuffer(bytes);
        Assert.Equal("\\music", r.ReadString());
    }

    [Fact]
    public void FolderContentsReply_Parse()
    {
        var w = new WriteBuffer();
        w.WriteInt32(1);
        w.WriteString("\\music");
        w.WriteInt32(1);
        w.WriteInt32(0);
        w.WriteString("\\music\\song.mp3");
        w.WriteUint64(5000000);
        w.WriteString("mp3");
        w.WriteInt32(2);
        w.WriteInt32(0); w.WriteInt32(320);
        w.WriteInt32(1); w.WriteInt32(300);

        var reply = FolderContentsReply.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Single(reply.Folders);
        Assert.Equal("\\music", reply.Folders[0].Path);
        Assert.Single(reply.Folders[0].Files);
        Assert.Equal("\\music\\song.mp3", reply.Folders[0].Files[0].Filename);
        Assert.Equal(5000000L, reply.Folders[0].Files[0].Size);
    }

    [Fact]
    public void WishlistReply_Parse()
    {
        var w = new WriteBuffer();
        w.WriteString("wisher");
        w.WriteInt32(42);
        w.WriteInt32(3);
        w.WriteInt32(50000);
        w.WriteInt32(1);
        w.WriteInt32(1);
        w.WriteInt32(101);
        w.WriteString("wish.mp3");
        w.WriteInt32(2000000);
        w.WriteString("mp3");
        w.WriteInt32(0);

        var reply = WishlistReply.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Equal("wisher", reply.Username);
        Assert.Equal(42, reply.Ticket);
        Assert.Single(reply.Files);
    }

    [Fact]
    public void RoomMessage_Parse()
    {
        var w = new WriteBuffer();
        w.WriteString("#chat");
        w.WriteString("speaker");
        w.WriteString("hello room");
        var msg = RoomMessageData.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Equal("#chat", msg.RoomName);
        Assert.Equal("speaker", msg.Username);
        Assert.Equal("hello room", msg.Message);
    }

    [Fact]
    public void UserJoinedRoom_Parse()
    {
        var w = new WriteBuffer();
        w.WriteString("#room");
        w.WriteString("newuser");
        w.WriteInt32(2);
        w.WriteInt32(1000);
        w.WriteInt32(50);
        w.WriteInt32(5);

        var joined = UserJoinedRoom.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Equal("#room", joined.RoomName);
        Assert.Equal("newuser", joined.Username);
        Assert.Equal(2, joined.FreeUploadSlots);
        Assert.Equal(5, joined.DirectoryCount);
    }

    [Fact]
    public void UserJoinedRoom_Parse_ShortFormat()
    {
        var w = new WriteBuffer();
        w.WriteString("#room");
        w.WriteString("minimal");

        var joined = UserJoinedRoom.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Equal("#room", joined.RoomName);
        Assert.Equal("minimal", joined.Username);
        Assert.Equal(0, joined.FreeUploadSlots);
    }

    [Fact]
    public void RoomList_Parse()
    {
        var w = new WriteBuffer();
        w.WriteInt32(2);
        w.WriteString("#soulseek");
        w.WriteInt32(100);
        w.WriteString("#music");
        w.WriteInt32(50);

        var list = RoomList.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Equal(2, list.Rooms.Count);
        Assert.Equal("#soulseek", list.Rooms[0].Name);
        Assert.Equal(100, list.Rooms[0].UserCount);
    }

    [Fact]
    public void JoinRoom_SerializesCorrectly()
    {
        var msg = new JoinRoom("#test");
        var bytes = msg.Serialize().ToBytes();
        var r = new ReadBuffer(bytes);
        Assert.Equal("#test", r.ReadString());
    }

    [Fact]
    public void LeaveRoom_SerializesCorrectly()
    {
        var msg = new LeaveRoom("#test");
        var bytes = msg.Serialize().ToBytes();
        var r = new ReadBuffer(bytes);
        Assert.Equal("#test", r.ReadString());
    }

    [Fact]
    public void SendRoomMessage_SerializesCorrectly()
    {
        var msg = new SendRoomMessage("#room", "hello");
        var bytes = msg.Serialize().ToBytes();
        var r = new ReadBuffer(bytes);
        Assert.Equal("#room", r.ReadString());
        Assert.Equal("hello", r.ReadString());
    }

    [Fact]
    public void UserLeftRoom_Parse()
    {
        var w = new WriteBuffer();
        w.WriteString("#room");
        w.WriteString("goneuser");
        var left = UserLeftRoom.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Equal("#room", left.RoomName);
        Assert.Equal("goneuser", left.Username);
    }

    [Fact]
    public void CheckDownloadQueue_SerializesCorrectly()
    {
        var msg = new CheckDownloadQueue(["user1", "user2"]);
        var bytes = msg.Serialize().ToBytes();
        var r = new ReadBuffer(bytes);
        Assert.Equal(2, r.ReadInt32());
        Assert.Equal("user1", r.ReadString());
        Assert.Equal("user2", r.ReadString());
    }

    [Fact]
    public void AddUserResponse_Parse()
    {
        var w = new WriteBuffer();
        w.WriteString("newuser");
        w.WriteInt32(1);
        w.WriteInt32(2);
        var resp = AddUserResponse.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Equal("newuser", resp.Username);
        Assert.True(resp.Exists);
        Assert.Equal(2, resp.Status);
    }

    [Fact]
    public void PeerAddressResponse_Parse()
    {
        var w = new WriteBuffer();
        w.WriteString("remoteuser");
        w.WriteInt32(0x7F000001);
        w.WriteInt32(2244);
        var resp = PeerAddressResponse.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Equal("remoteuser", resp.Username);
        Assert.Equal(0x7F000001, resp.Ip);
        Assert.Equal(2244, resp.Port);
    }

    [Fact]
    public void SharedFile_Parse_WithLargeSize()
    {
        var w = new WriteBuffer();
        w.WriteInt32(0);
        w.WriteString("bigfile.iso");
        w.WriteUint64(0x1000000000);
        w.WriteString("iso");
        w.WriteInt32(0);
        var file = SharedFile.Parse(new ReadBuffer(w.ToBytes()));
        Assert.Equal(0x1000000000L, file.Size);
    }

    [Fact]
    public void RoomTickerSet_SerializesCorrectly()
    {
        var msg = new RoomTickerSet("#room", "currently playing...");
        var bytes = msg.Serialize().ToBytes();
        var r = new ReadBuffer(bytes);
        Assert.Equal("#room", r.ReadString());
        Assert.Equal("currently playing...", r.ReadString());
    }

    [Fact]
    public void WishlistInclusion_Add_SerializesCorrectly()
    {
        var msg = new WishlistInclusion(true, "album name");
        var bytes = msg.Serialize().ToBytes();
        var r = new ReadBuffer(bytes);
        Assert.Equal(1, r.ReadInt32());
        Assert.Equal("album name", r.ReadString());
    }

    [Fact]
    public void WishlistInclusion_Remove_SerializesCorrectly()
    {
        var msg = new WishlistInclusion(false, "old phrase");
        var bytes = msg.Serialize().ToBytes();
        var r = new ReadBuffer(bytes);
        Assert.Equal(0, r.ReadInt32());
        Assert.Equal("old phrase", r.ReadString());
    }

    [Fact]
    public void UserInfoRequest_SerializesCorrectly()
    {
        var req = new UserInfoRequest();
        Assert.Empty(req.Serialize().ToBytes());
    }
}