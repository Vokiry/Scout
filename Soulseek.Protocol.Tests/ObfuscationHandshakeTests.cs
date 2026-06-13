using Soulseek.Protocol.Obfuscation;

namespace Soulseek.Protocol.Tests;

public class ObfuscationHandshakeTests
{
    [Fact]
    public void GenerateToken_ReturnsNonZero()
    {
        var token = ObfuscationHandshake.GenerateToken();
        Assert.NotEqual(0, token);
    }

    [Fact]
    public void GenerateToken_ProducesDifferentValues()
    {
        var tokens = Enumerable.Range(0, 10).Select(_ => ObfuscationHandshake.GenerateToken()).ToArray();
        Assert.True(tokens.Distinct().Count() > 1);
    }

    [Fact]
    public void Initiate_CreatesHandshake()
    {
        var handshake = ObfuscationHandshake.Initiate(12345);
        Assert.NotNull(handshake);
        Assert.NotEqual(0, handshake.OurToken);
        Assert.Equal(12345, handshake.PeerToken);
    }

    [Fact]
    public void Respond_CreatesHandshake()
    {
        var handshake = ObfuscationHandshake.Respond(67890);
        Assert.NotNull(handshake);
        Assert.NotEqual(0, handshake.OurToken);
        Assert.Equal(67890, handshake.PeerToken);
    }

    [Fact]
    public void ComputeKey_Returns256Bytes()
    {
        var handshake = ObfuscationHandshake.Initiate(42);
        var key = handshake.ComputeKey();
        Assert.Equal(256, key.Length);
    }

    [Fact]
    public void SameTokens_ProduceSameKey()
    {
        var h1 = ObfuscationHandshake.Initiate(100);
        var h2 = ObfuscationHandshake.Respond(100);
        // They started differently (different OurToken), so keys will differ
        var key1 = h1.ComputeKey();
        var key2 = h2.ComputeKey();
        Assert.NotEqual(key1, key2);
    }

    [Fact]
    public void EncodeDecode_RoundTrip()
    {
        var handshake = ObfuscationHandshake.Initiate(0xFF);
        var key = handshake.ComputeKey();
        var original = new byte[] { 0x01, 0x02, 0x03, 0x04, 0x05 };
        var encoded = handshake.Encode(original, key);
        var decoded = handshake.Decode(encoded, key);
        Assert.Equal(original, decoded);
    }

    [Fact]
    public void Encode_ChangesData()
    {
        var handshake = ObfuscationHandshake.Initiate(0x1234);
        var key = handshake.ComputeKey();
        var original = new byte[] { 0x00, 0x00, 0x00, 0x00 };
        var encoded = handshake.Encode(original, key);
        Assert.NotEqual(original, encoded);
    }

    [Fact]
    public void Decode_IsAliasForEncode()
    {
        var handshake = ObfuscationHandshake.Initiate(0xAA);
        var key = handshake.ComputeKey();
        var data = new byte[] { 0xFF, 0xEE };
        Assert.Equal(handshake.Encode(data, key), handshake.Decode(data, key));
    }

    [Fact]
    public void Key_DifferentForDifferentPeerTokens()
    {
        var h1 = ObfuscationHandshake.Initiate(1);
        var h2 = ObfuscationHandshake.Initiate(2);
        var key1 = h1.ComputeKey();
        var key2 = h2.ComputeKey();
        Assert.NotEqual(key1, key2);
    }
}