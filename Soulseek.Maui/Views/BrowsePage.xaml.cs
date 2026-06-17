using Soulseek.Maui.ViewModels;

namespace Soulseek.Maui.Views;

public partial class BrowsePage : ContentPage
{
    public BrowsePage(BrowseViewModel vm)
    {
        InitializeComponent();
        BindingContext = vm;
    }
}
