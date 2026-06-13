using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Soulseek.Client;

class Program
{
    static async Task Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.WriteLine("Usage: Soulseek.Client <username> <password>");
            return;
        }

        var username = args[0];
        var password = args[1];

        using var host = Host.CreateDefaultBuilder(args)
            .ConfigureLogging(logging =>
            {
                logging.ClearProviders();
                logging.AddConsole();
                logging.SetMinimumLevel(LogLevel.Information);
            })
            .Build();

        var logger = host.Services.GetRequiredService<ILogger<ConsoleClient>>();
        var client = new ConsoleClient(logger);

        await client.RunAsync(username, password);
    }
}