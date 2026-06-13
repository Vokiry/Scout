using Soulseek.Maui.ViewModels;

namespace Soulseek.Maui.Views;

public partial class DownloadsPage : ContentPage
{
    private readonly DownloadsViewModel _vm;
    public DownloadsPage(DownloadsViewModel vm)
    {
        InitializeComponent();
        _vm = vm;
        BindingContext = vm;
    }
    protected override void OnAppearing()
    {
        base.OnAppearing();
        _vm.OnAppearing();
    }
}
