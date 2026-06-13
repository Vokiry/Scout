using Soulseek.Maui.ViewModels;

namespace Soulseek.Maui.Views;

public partial class LoginPage : ContentPage
{
    public LoginPage(LoginViewModel vm)
    {
        InitializeComponent();
        BindingContext = vm;
    }
}
