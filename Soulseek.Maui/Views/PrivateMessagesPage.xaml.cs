using Soulseek.Maui.ViewModels;

namespace Soulseek.Maui.Views;

public partial class PrivateMessagesPage : ContentPage
{
    private readonly PrivateMessagesViewModel _vm;
    public PrivateMessagesPage(PrivateMessagesViewModel vm)
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
