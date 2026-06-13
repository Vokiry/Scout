using Soulseek.Protocol.Connection;
using Soulseek.Protocol.Messages;

namespace Soulseek.Protocol.Services;

public class RoomChatService
{
    private readonly IServerTransport _server;
    private readonly Subject<RoomMessageData> _roomMessagesSubject = new();
    private readonly Subject<UserJoinedRoom> _userJoinedSubject = new();
    private readonly Subject<UserLeftRoom> _userLeftSubject = new();
    private readonly Subject<RoomList> _roomListSubject = new();
    private IDisposable? _messageSub;

    public RoomChatService(IServerTransport server)
    {
        _server = server;
    }

    public IObservable<RoomMessageData> RoomMessages => _roomMessagesSubject;
    public IObservable<UserJoinedRoom> UserJoined => _userJoinedSubject;
    public IObservable<UserLeftRoom> UserLeft => _userLeftSubject;
    public IObservable<RoomList> RoomList => _roomListSubject;

    public void Init()
    {
        _messageSub = _server.Messages.Subscribe(OnMessage);
    }

    public void JoinRoom(string roomName)
    {
        _server.SendMessage(new SoulseekMessage(
            ServerCode.JoinRoom,
            new JoinRoom(roomName).Serialize().ToBytes()
        ));
    }

    public void LeaveRoom(string roomName)
    {
        _server.SendMessage(new SoulseekMessage(
            ServerCode.LeaveRoom,
            new LeaveRoom(roomName).Serialize().ToBytes()
        ));
    }

    public void SendMessage(string roomName, string message)
    {
        _server.SendMessage(new SoulseekMessage(
            ServerCode.RoomMessage,
            new SendRoomMessage(roomName, message).Serialize().ToBytes()
        ));
    }

    public void RequestRoomList()
    {
        _server.SendMessage(new SoulseekMessage(
            ServerCode.RoomList,
            new WriteBuffer().ToBytes()
        ));
    }

    public void SetRoomTicker(string roomName, string ticker)
    {
        _server.SendMessage(new SoulseekMessage(
            ServerCode.RoomTickerSet,
            new RoomTickerSet(roomName, ticker).Serialize().ToBytes()
        ));
    }

    public void RemoveRoomTicker(string roomName)
    {
        _server.SendMessage(new SoulseekMessage(
            ServerCode.RoomTickerRemove,
            new RoomTickerRemove(roomName).Serialize().ToBytes()
        ));
    }

    private void OnMessage(SoulseekMessage message)
    {
        try
        {
            switch (message.Code)
            {
                case ServerCode.RoomMessage:
                    var msg = RoomMessageData.Parse(new ReadBuffer(message.Payload));
                    _roomMessagesSubject.OnNext(msg);
                    break;
                case ServerCode.UserJoinedRoom:
                    var joined = UserJoinedRoom.Parse(new ReadBuffer(message.Payload));
                    _userJoinedSubject.OnNext(joined);
                    break;
                case ServerCode.UserLeftRoom:
                    var left = UserLeftRoom.Parse(new ReadBuffer(message.Payload));
                    _userLeftSubject.OnNext(left);
                    break;
                case ServerCode.RoomList:
                    var list = RoomList.Parse(new ReadBuffer(message.Payload));
                    _roomListSubject.OnNext(list);
                    break;
            }
        }
        catch
        {
            // Skip malformed room messages
        }
    }

    public void Dispose()
    {
        _messageSub?.Dispose();
    }
}