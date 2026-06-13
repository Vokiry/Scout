using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace Soulseek.Maui.ViewModels;

public partial class WishlistViewModel : ObservableObject
{
    private readonly Services.SoulseekClientService _client;
    private readonly Services.SettingsService _settings;

    [ObservableProperty] private string _newPhrase = string.Empty;
    [ObservableProperty] private string _statusText = "";

    public ObservableCollection<string> Items { get; } = new();

    public WishlistViewModel(Services.SoulseekClientService client, Services.SettingsService settings)
    {
        _client = client;
        _settings = settings;
        LoadSaved();
    }

    private void LoadSaved()
    {
        var saved = Preferences.Get("wishlist", "");
        foreach (var item in saved.Split('\n', StringSplitOptions.RemoveEmptyEntries))
            Items.Add(item);
    }

    private void Save()
    {
        Preferences.Set("wishlist", string.Join("\n", Items));
    }

    [RelayCommand]
    private void AddItem()
    {
        if (string.IsNullOrWhiteSpace(NewPhrase)) return;
        if (Items.Contains(NewPhrase.Trim()))
        {
            StatusText = "Already in wishlist";
            return;
        }
        _client.AddWishlistItem(NewPhrase.Trim());
        Items.Add(NewPhrase.Trim());
        Save();
        NewPhrase = string.Empty;
        StatusText = "Added to wishlist";
    }

    [RelayCommand]
    private void RemoveItem(string phrase)
    {
        if (string.IsNullOrEmpty(phrase)) return;
        _client.RemoveWishlistItem(phrase);
        Items.Remove(phrase);
        Save();
        StatusText = "Removed from wishlist";
    }
}
