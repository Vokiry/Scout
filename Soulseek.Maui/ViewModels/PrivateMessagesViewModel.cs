using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Soulseek.Protocol;
using Soulseek.Protocol.Messages;

namespace Soulseek.Maui.ViewModels;

public partial class PrivateMessageItem : ObservableObject
{
    [ObservableProperty] private string _username = string.Empty;
    [ObservableProperty] private string _message = string.Empty;
    [ObservableProperty] private string _timestamp = string.Empty;
    [ObservableProperty] private bool _isOutgoing;
}

public partial class ConversationItem : ObservableObject
{
    [ObservableProperty] private string _username = string.Empty;
    [ObservableProperty] private string _lastMessage = string.Empty;
    [ObservableProperty] private string _lastTimestamp = string.Empty;
    [ObservableProperty] private int _unreadCount;
}

public partial class PrivateMessagesViewModel : ObservableObject
{
    private readonly Services.SoulseekClientService _client;
    private readonly Services.NotificationService _notifications;
    private readonly Services.SettingsService _settings;

    [ObservableProperty] private string _recipient = string.Empty;
    [ObservableProperty] private string _messageText = string.Empty;
    [ObservableProperty] private ConversationItem? _selectedConversation;

    public ObservableCollection<PrivateMessageItem> Messages { get; } = new();
    public ObservableCollection<ConversationItem> Conversations { get; } = new();

    private IDisposable? _sub;
    private readonly Dictionary<string, List<PrivateMessageItem>> _conversations = new();

    public PrivateMessagesViewModel(
        Services.SoulseekClientService client,
        Services.NotificationService notifications,
        Services.SettingsService settings)
    {
        _client = client;
        _notifications = notifications;
        _settings = settings;
    }

    public void OnAppearing()
    {
        _sub ??= _client.Client.PrivateMessages.Subscribe(pm =>
        {
            MainThread.BeginInvokeOnMainThread(() =>
            {
                var item = new PrivateMessageItem
                {
                    Username = pm.Username,
                    Message = pm.Message,
                    Timestamp = DateTime.Now.ToString("HH:mm"),
                    IsOutgoing = false,
                };

                if (!_conversations.ContainsKey(pm.Username))
                    _conversations[pm.Username] = new List<PrivateMessageItem>();

                _conversations[pm.Username].Add(item);

                if (SelectedConversation?.Username == pm.Username)
                    Messages.Add(item);

                UpdateConversationList(pm.Username, pm.Message);

                if (_settings.NotificationsEnabled)
                    _notifications.ShowPmNotification(pm.Username, pm.Message);
            });
        });
    }

    private void UpdateConversationList(string username, string lastMsg)
    {
        var existing = Conversations.FirstOrDefault(c => c.Username == username);
        if (existing != null)
        {
            existing.LastMessage = lastMsg;
            existing.LastTimestamp = DateTime.Now.ToString("HH:mm");
            if (SelectedConversation?.Username != username)
                existing.UnreadCount++;
            Conversations.Move(Conversations.IndexOf(existing), 0);
        }
        else
        {
            Conversations.Insert(0, new ConversationItem
            {
                Username = username,
                LastMessage = lastMsg,
                LastTimestamp = DateTime.Now.ToString("HH:mm"),
                UnreadCount = SelectedConversation?.Username == username ? 0 : 1,
            });
        }
    }

    partial void OnSelectedConversationChanged(ConversationItem? value)
    {
        Messages.Clear();
        if (value != null)
        {
            Recipient = value.Username;
            value.UnreadCount = 0;
            if (_conversations.TryGetValue(value.Username, out var msgs))
                foreach (var m in msgs)
                    Messages.Add(m);
        }
    }

    [RelayCommand]
    private void SendMessage()
    {
        if (string.IsNullOrWhiteSpace(MessageText) || string.IsNullOrWhiteSpace(Recipient)) return;
        _client.SendPrivateMessage(Recipient, MessageText);
        var item = new PrivateMessageItem
        {
            Username = Recipient,
            Message = MessageText,
            Timestamp = DateTime.Now.ToString("HH:mm"),
            IsOutgoing = true,
        };
        if (!_conversations.ContainsKey(Recipient))
            _conversations[Recipient] = new List<PrivateMessageItem>();
        _conversations[Recipient].Add(item);
        Messages.Add(item);
        UpdateConversationList(Recipient, MessageText);
        MessageText = string.Empty;
    }

    [RelayCommand]
    private void SelectConversation(ConversationItem item)
    {
        SelectedConversation = item;
    }
}
