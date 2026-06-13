using Soulseek.Maui.ViewModels;

namespace Soulseek.Maui.Views;

public partial class RoomsPage : ContentPage
{
    private readonly RoomsViewModel _vm;
    public RoomsPage(RoomsViewModel vm)
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
