using Soulseek.Protocol.Connection;
using Soulseek.Protocol.Messages;
using Xunit;
using Soulseek.Protocol.Services;

namespace Soulseek.Protocol.Tests.Services;

public class SearchServiceTests
{
    [Fact]
    public void Search_SendsMessageWithTicket()
    {
        var transport = new MockServerTransport();
        var service = new SearchService(transport);
        service.Init();

        SoulseekMessage? sent = null;
        transport.MessageSent += msg => sent = msg;

        var ticket = service.Search("test query");

        Assert.NotNull(sent);
        Assert.Equal(ServerCode.SearchRequest, sent.Value.Code);
        var r = new ReadBuffer(sent.Value.Payload);
        Assert.Equal(ticket, r.ReadInt32());
        Assert.Equal("test query", r.ReadString());
    }

    [Fact]
    public void Search_ReturnsIncrementingTickets()
    {
        var transport = new MockServerTransport();
        var service = new SearchService(transport);
        service.Init();

        Assert.Equal(1, service.Search("a"));
        Assert.Equal(2, service.Search("b"));
        Assert.Equal(3, service.Search("c"));
    }

    [Fact]
    public void SearchResponse_RoutesToResults()
    {
        var transport = new MockServerTransport();
        var service = new SearchService(transport);
        service.Init();

        SearchResult? result = null;
        using var sub = service.Results.Subscribe(r => result = r);

        var w = new WriteBuffer();
        w.WriteString("responder");
        w.WriteInt32(1);
        w.WriteInt32(10);
        w.WriteInt32(3);
        w.WriteInt32(50000);
        w.WriteInt32(0);
        w.WriteInt32(0);

        transport.SimulateMessage(ServerCode.SearchResponse, w.ToBytes());

        Assert.NotNull(result);
        Assert.Equal("responder", result.Username);
        Assert.Equal(3, result.FreeUploadSlots);
    }

    [Fact]
    public void UserSearchResponse_IsAlsoRouted()
    {
        var transport = new MockServerTransport();
        var service = new SearchService(transport);
        service.Init();

        var received = false;
        using var sub = service.Results.Subscribe(_ => received = true);

        var w = new WriteBuffer();
        w.WriteString("user");
        w.WriteInt32(1);
        w.WriteInt32(0);
        w.WriteInt32(0);
        w.WriteInt32(0);
        w.WriteInt32(0);
        w.WriteInt32(0);

        transport.SimulateMessage(ServerCode.UserSearchResponse, w.ToBytes());
        Assert.True(received);
    }

    [Fact]
    public void UnrelatedMessage_IsIgnored()
    {
        var transport = new MockServerTransport();
        var service = new SearchService(transport);
        service.Init();

        var received = false;
        using var sub = service.Results.Subscribe(_ => received = true);
        transport.SimulateMessage(ServerCode.Ping, []);
        Assert.False(received);
    }

    [Fact]
    public void Dispose_CleansUpSubscription()
    {
        var transport = new MockServerTransport();
        var service = new SearchService(transport);
        service.Init();

        service.Dispose();
        var received = false;
        using var sub = service.Results.Subscribe(_ => received = true);
        transport.SimulateMessage(ServerCode.SearchResponse, new byte[8]);
        Assert.False(received);
    }
}

public class ChatServiceTests
{
    [Fact]
    public void SendPrivateMessage_EncodesCorrectly()
    {
        var transport = new MockServerTransport();
        var service = new ChatService(transport);
        service.Init();

        SoulseekMessage? sent = null;
        transport.MessageSent += msg => sent = msg;

        service.SendPrivateMessage("bob", "hello");
        Assert.NotNull(sent);
        Assert.Equal(ServerCode.PrivateMessage, sent.Value.Code);
        var r = new ReadBuffer(sent.Value.Payload);
        Assert.Equal("bob", r.ReadString());
        Assert.Equal("hello", r.ReadString());
    }

    [Fact]
    public void PrivateMessage_IsRouted()
    {
        var transport = new MockServerTransport();
        var service = new ChatService(transport);
        service.Init();

        PrivateMessage? result = null;
        using var sub = service.PrivateMessages.Subscribe(m => result = m);

        var w = new WriteBuffer();
        w.WriteString("alice");
        w.WriteString("hi");
        w.WriteInt32(1000);
        transport.SimulateMessage(ServerCode.PrivateMessage, w.ToBytes());

        Assert.NotNull(result);
        Assert.Equal("alice", result.Username);
        Assert.Equal("hi", result.Message);
        Assert.Equal(1000, result.Timestamp);
    }
}

public class UserServiceTests
{
    [Fact]
    public void AddUser_SendsMessage()
    {
        var transport = new MockServerTransport();
        var service = new UserService(transport);
        service.Init();

        SoulseekMessage? sent = null;
        transport.MessageSent += msg => sent = msg;

        service.AddUser("newuser");
        Assert.NotNull(sent);
        Assert.Equal(ServerCode.AddUser, sent.Value.Code);
        var r = new ReadBuffer(sent.Value.Payload);
        Assert.Equal("newuser", r.ReadString());
    }

    [Fact]
    public void UserStatus_IsRouted()
    {
        var transport = new MockServerTransport();
        var service = new UserService(transport);
        service.Init();

        UserStatusMessage? result = null;
        using var sub = service.UserStatus.Subscribe(s => result = s);

        var w = new WriteBuffer();
        w.WriteString("user1");
        w.WriteInt32(2);
        transport.SimulateMessage(ServerCode.StatusResponse, w.ToBytes());

        Assert.NotNull(result);
        Assert.Equal("user1", result.Username);
        Assert.Equal(2, result.Status);
    }
}

public class WishlistServiceTests
{
    [Fact]
    public void WishlistSearch_SendsMessage()
    {
        var transport = new MockServerTransport();
        var service = new WishlistService(transport);
        service.Init();

        SoulseekMessage? sent = null;
        transport.MessageSent += msg => sent = msg;

        service.WishlistSearch("favorite album");
        Assert.NotNull(sent);
        Assert.Equal(ServerCode.Wishes, sent.Value.Code);
    }

    [Fact]
    public void AddWishlistItem_SendsInclusion()
    {
        var transport = new MockServerTransport();
        var service = new WishlistService(transport);
        service.Init();

        SoulseekMessage? sent = null;
        transport.MessageSent += msg => sent = msg;

        service.AddWishlistItem("phrase");
        Assert.NotNull(sent);
        Assert.Equal(ServerCode.WishlistInclusion, sent.Value.Code);
    }

    [Fact]
    public void WishReply_IsRouted()
    {
        var transport = new MockServerTransport();
        var service = new WishlistService(transport);
        service.Init();

        WishlistReply? result = null;
        using var sub = service.WishlistResults.Subscribe(r => result = r);

        var w = new WriteBuffer();
        w.WriteString("user");
        w.WriteInt32(1);
        w.WriteInt32(2);
        w.WriteInt32(5000);
        w.WriteInt32(0);
        w.WriteInt32(0);

        transport.SimulateMessage(ServerCode.WishReply, w.ToBytes());
        Assert.NotNull(result);
    }

    [Fact]
    public void RemoveWishlistItem_SendsRemoval()
    {
        var transport = new MockServerTransport();
        var service = new WishlistService(transport);
        service.Init();

        SoulseekMessage? sent = null;
        transport.MessageSent += msg => sent = msg;

        service.RemoveWishlistItem("old");
        Assert.NotNull(sent);
        var r = new ReadBuffer(sent.Value.Payload);
        Assert.Equal(0, r.ReadInt32());
        Assert.Equal("old", r.ReadString());
    }
}

public class RoomChatServiceTests
{
    [Fact]
    public void JoinRoom_SendsMessage()
    {
        var transport = new MockServerTransport();
        var service = new RoomChatService(transport);
        service.Init();

        SoulseekMessage? sent = null;
        transport.MessageSent += msg => sent = msg;

        service.JoinRoom("#music");
        Assert.Equal(ServerCode.JoinRoom, sent?.Code);
    }

    [Fact]
    public void RoomMessage_IsRouted()
    {
        var transport = new MockServerTransport();
        var service = new RoomChatService(transport);
        service.Init();

        RoomMessageData? result = null;
        using var sub = service.RoomMessages.Subscribe(m => result = m);

        var w = new WriteBuffer();
        w.WriteString("#room");
        w.WriteString("speaker");
        w.WriteString("text");
        transport.SimulateMessage(ServerCode.RoomMessage, w.ToBytes());

        Assert.NotNull(result);
        Assert.Equal("#room", result.RoomName);
        Assert.Equal("speaker", result.Username);
        Assert.Equal("text", result.Message);
    }

    [Fact]
    public void LeaveRoom_SendsMessage()
    {
        var transport = new MockServerTransport();
        var service = new RoomChatService(transport);
        service.Init();

        SoulseekMessage? sent = null;
        transport.MessageSent += msg => sent = msg;

        service.LeaveRoom("#room");
        Assert.Equal(ServerCode.LeaveRoom, sent?.Code);
    }

    [Fact]
    public void SendMessage_SendsCorrectly()
    {
        var transport = new MockServerTransport();
        var service = new RoomChatService(transport);
        service.Init();

        SoulseekMessage? sent = null;
        transport.MessageSent += msg => sent = msg;

        service.SendMessage("#chat", "hello");
        Assert.Equal(ServerCode.RoomMessage, sent?.Code);
        var r = new ReadBuffer(sent!.Value.Payload);
        Assert.Equal("#chat", r.ReadString());
        Assert.Equal("hello", r.ReadString());
    }

    [Fact]
    public void UserJoined_IsRouted()
    {
        var transport = new MockServerTransport();
        var service = new RoomChatService(transport);
        service.Init();

        UserJoinedRoom? result = null;
        using var sub = service.UserJoined.Subscribe(u => result = u);

        var w = new WriteBuffer();
        w.WriteString("#room");
        w.WriteString("newbie");
        transport.SimulateMessage(ServerCode.UserJoinedRoom, w.ToBytes());

        Assert.NotNull(result);
        Assert.Equal("#room", result.RoomName);
        Assert.Equal("newbie", result.Username);
    }

    [Fact]
    public void UserLeft_IsRouted()
    {
        var transport = new MockServerTransport();
        var service = new RoomChatService(transport);
        service.Init();

        UserLeftRoom? result = null;
        using var sub = service.UserLeft.Subscribe(u => result = u);

        var w = new WriteBuffer();
        w.WriteString("#room");
        w.WriteString("leaver");
        transport.SimulateMessage(ServerCode.UserLeftRoom, w.ToBytes());

        Assert.NotNull(result);
    }

    [Fact]
    public void RoomList_IsRouted()
    {
        var transport = new MockServerTransport();
        var service = new RoomChatService(transport);
        service.Init();

        RoomList? result = null;
        using var sub = service.RoomList.Subscribe(l => result = l);

        var w = new WriteBuffer();
        w.WriteInt32(1);
        w.WriteString("#test");
        w.WriteInt32(10);
        transport.SimulateMessage(ServerCode.RoomList, w.ToBytes());

        Assert.NotNull(result);
        Assert.Single(result.Rooms);
    }

    [Fact]
    public void RequestRoomList_SendsEmptyPayload()
    {
        var transport = new MockServerTransport();
        var service = new RoomChatService(transport);
        service.Init();

        SoulseekMessage? sent = null;
        transport.MessageSent += msg => sent = msg;

        service.RequestRoomList();
        Assert.Equal(ServerCode.RoomList, sent?.Code);
        Assert.Empty(sent!.Value.Payload);
    }

    [Fact]
    public void SetRoomTicker_SendsCorrectly()
    {
        var transport = new MockServerTransport();
        var service = new RoomChatService(transport);
        service.Init();

        SoulseekMessage? sent = null;
        transport.MessageSent += msg => sent = msg;

        service.SetRoomTicker("#room", "now playing: song");
        Assert.Equal(ServerCode.RoomTickerSet, sent?.Code);
    }

    [Fact]
    public void RemoveRoomTicker_SendsCorrectly()
    {
        var transport = new MockServerTransport();
        var service = new RoomChatService(transport);
        service.Init();

        SoulseekMessage? sent = null;
        transport.MessageSent += msg => sent = msg;

        service.RemoveRoomTicker("#room");
        Assert.Equal(ServerCode.RoomTickerRemove, sent?.Code);
    }
}

internal class MockServerTransport : IServerTransport
{
    private readonly Subject<ServerConnectionState> _stateSubject = new();
    private readonly Subject<SoulseekMessage> _messageSubject = new();
    private readonly Subject<ConnectionInfo> _infoSubject = new();

    public event Action<SoulseekMessage>? MessageSent;

    public IObservable<ServerConnectionState> StateChanges => _stateSubject;
    public IObservable<SoulseekMessage> MessageStream => _messageSubject;
    public IObservable<ConnectionInfo> ConnectionInfo => _infoSubject;
    public ServerConnectionState State => ServerConnectionState.Connected;
    public bool Authenticated => true;
    public string? Username => "testuser";

    public void Init() { }
    public void SetServer(string host, int port) { }

    public Task Connect(string username, string password)
    {
        _stateSubject.OnNext(ServerConnectionState.Connected);
        return Task.CompletedTask;
    }

    public Task Disconnect()
    {
        _stateSubject.OnNext(ServerConnectionState.Disconnected);
        return Task.CompletedTask;
    }

    public void SendMessage(SoulseekMessage message) => MessageSent?.Invoke(message);
    public void SendRaw(int code, byte[] payload) => MessageSent?.Invoke(new SoulseekMessage(code, payload));

    public void SimulateMessage(int code, byte[] payload)
    {
        _messageSubject.OnNext(new SoulseekMessage(code, payload));
    }

    public void Dispose()
    {
        _stateSubject.Dispose();
        _messageSubject.Dispose();
        _infoSubject.Dispose();
    }
}