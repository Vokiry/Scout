using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace Soulseek.Maui.ViewModels;

public partial class RoomMessageItem : ObservableObject
{
    [ObservableProperty] private string _roomName = string.Empty;
    [ObservableProperty] private string _username = string.Empty;
    [ObservableProperty] private string _message = string.Empty;
    [ObservableProperty] private string _timestamp = string.Empty;
}

public partial class JoinedRoomItem : ObservableObject
{
    [ObservableProperty] private string _name = string.Empty;
    public override string ToString() => Name;
}

public partial class RoomsViewModel : ObservableObject
{
    private readonly Services.SoulseekClientService _client;

    [ObservableProperty] private string _currentRoom = string.Empty;
    [ObservableProperty] private string _messageText = string.Empty;
    [ObservableProperty] private string _joinRoomName = string.Empty;
    [ObservableProperty] private JoinedRoomItem? _selectedRoom;

    public ObservableCollection<RoomMessageItem> Messages { get; } = new();
    public ObservableCollection<JoinedRoomItem> JoinedRooms { get; } = new();

    private IDisposable? _msgSub;

    public RoomsViewModel(Services.SoulseekClientService client)
    {
        _client = client;
    }

    public void OnAppearing()
    {
        _msgSub ??= _client.Client.RoomMessages.Subscribe(msg =>
        {
            MainThread.BeginInvokeOnMainThread(() =>
            {
                Messages.Add(new RoomMessageItem
                {
                    RoomName = msg.RoomName,
                    Username = msg.Username,
                    Message = msg.Message,
                    Timestamp = DateTime.Now.ToString("HH:mm"),
                });
            });
        });
    }

    partial void OnSelectedRoomChanged(JoinedRoomItem? value)
    {
        if (value != null)
        {
            CurrentRoom = value.Name;
            Messages.Clear();
        }
    }

    [RelayCommand]
    private void JoinRoom()
    {
        if (string.IsNullOrWhiteSpace(JoinRoomName)) return;
        _client.JoinRoom(JoinRoomName);
        if (!JoinedRooms.Any(r => r.Name == JoinRoomName))
            JoinedRooms.Add(new JoinedRoomItem { Name = JoinRoomName });
        CurrentRoom = JoinRoomName;
        Messages.Clear();
        SelectedRoom = JoinedRooms.FirstOrDefault(r => r.Name == JoinRoomName);
        JoinRoomName = string.Empty;
    }

    [RelayCommand]
    private void SendMessage()
    {
        if (string.IsNullOrWhiteSpace(MessageText) || string.IsNullOrWhiteSpace(CurrentRoom)) return;
        _client.SendRoomMessage(CurrentRoom, MessageText);
        Messages.Add(new RoomMessageItem
        {
            RoomName = CurrentRoom,
            Username = _client.Username ?? "You",
            Message = MessageText,
            Timestamp = DateTime.Now.ToString("HH:mm"),
        });
        MessageText = string.Empty;
    }

    [RelayCommand]
    private void LeaveRoom()
    {
        if (string.IsNullOrWhiteSpace(CurrentRoom)) return;
        _client.LeaveRoom(CurrentRoom);
        var room = JoinedRooms.FirstOrDefault(r => r.Name == CurrentRoom);
        if (room != null) JoinedRooms.Remove(room);
        Messages.Clear();
        CurrentRoom = JoinedRooms.FirstOrDefault()?.Name ?? "";
    }
}
