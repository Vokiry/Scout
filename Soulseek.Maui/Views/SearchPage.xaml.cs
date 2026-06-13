using Soulseek.Maui.ViewModels;

namespace Soulseek.Maui.Views;

public partial class SearchPage : ContentPage
{
    private readonly SearchViewModel _vm;
    public SearchPage(SearchViewModel vm)
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
