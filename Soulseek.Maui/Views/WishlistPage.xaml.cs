using Soulseek.Maui.ViewModels;

namespace Soulseek.Maui.Views;

public partial class WishlistPage : ContentPage
{
    public WishlistPage(WishlistViewModel vm)
    {
        InitializeComponent();
        BindingContext = vm;
    }
}
