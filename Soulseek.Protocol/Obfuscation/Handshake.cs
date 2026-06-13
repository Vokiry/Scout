namespace Soulseek.Protocol.Obfuscation;

public class ObfuscationHandshake
{
    private static readonly byte[] PiDigits = GeneratePiDigits(1024);

    public int OurToken { get; }
    public int PeerToken { get; }

    private ObfuscationHandshake(int ourToken, int peerToken)
    {
        OurToken = ourToken;
        PeerToken = peerToken;
    }

    public static int GenerateToken()
    {
        Span<byte> bytes = stackalloc byte[4];
        RandomNumberGenerator.Fill(bytes);
        return BitConverter.ToInt32(bytes);
    }

    public static ObfuscationHandshake Respond(int peerToken)
    {
        var ourToken = GenerateToken();
        return new ObfuscationHandshake(ourToken, peerToken);
    }

    public static ObfuscationHandshake Initiate(int peerToken)
    {
        var ourToken = GenerateToken();
        return new ObfuscationHandshake(ourToken, peerToken);
    }

    public byte[] ComputeKey()
    {
        var combined = OurToken ^ PeerToken;
        var key = new byte[256];

        for (int i = 0; i < 256; i++)
        {
            var piIndex = (combined + i) % PiDigits.Length;
            key[i] = (byte)(PiDigits[piIndex] ^ ((combined >> ((i % 4) * 8)) & 0xFF));
        }

        return key;
    }

    public byte[] Encode(byte[] data, byte[] key)
    {
        var result = new byte[data.Length];
        for (int i = 0; i < data.Length; i++)
            result[i] = (byte)(data[i] ^ key[i % key.Length]);
        return result;
    }

    public byte[] Decode(byte[] data, byte[] key) => Encode(data, key);

    private static byte[] GeneratePiDigits(int count)
    {
        const string piHex = "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89" +
            "452821E638D01377BE5466CF34E90C6CC0AC29B7C97C50DD3F84D5B5B5470917" +
            "9216D5D98979FB1BD1310BA698DFB5AC2FFD72DBD01ADFB7B8E1AFED6A267E96" +
            "BA7C9045F12C7F9924A19947B3916CF70801F2E2858EFC16636920D871574E69";

        var digits = new byte[count];
        for (int i = 0; i < count && i < piHex.Length / 2; i++)
            digits[i] = Convert.ToByte(piHex.Substring(i * 2, 2), 16);
        return digits;
    }
}

internal static class RandomNumberGenerator
{
    private static readonly Random _random = new();

    public static void Fill(Span<byte> buffer)
    {
        byte[] bytes = new byte[buffer.Length];
        lock (_random) { _random.NextBytes(bytes); }
        bytes.CopyTo(buffer);
    }

    public static int GetInt32(int toExclusive) => lock (_random) { _random.Next(toExclusive); }
}