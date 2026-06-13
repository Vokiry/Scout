using Soulseek.Protocol.Messages;

namespace Soulseek.Protocol.Tests.Messages;

public class SoulseekMessageTests
{
    [Fact]
    public void Encode_ProducesCorrectFormat()
    {
        var payload = new byte[] { 0x01, 0x02, 0x03 };
        var encoded = SoulseekMessage.Encode(42, payload);
        Assert.Equal(4 + 4 + 3, encoded.Length);

        var r = new ReadBuffer(encoded);
        var length = r.ReadUint32();
        Assert.Equal(4u + 3u, length);
        Assert.Equal(42, r.ReadInt32());
        Assert.Equal(payload, r.ReadRemaining());
    }

    [Fact]
    public void Parse_DecodesEncodedMessage()
    {
        var payload = new byte[] { 0xAA, 0xBB };
        var encoded = SoulseekMessage.Encode(123, payload);
        var parsed = SoulseekMessage.Parse(encoded);
        Assert.Equal(123, parsed.Code);
        Assert.Equal(payload, parsed.Payload);
    }

    [Fact]
    public void EncodeAndParse_RoundTrip_WithEmptyPayload()
    {
        var encoded = SoulseekMessage.Encode(0, []);
        var parsed = SoulseekMessage.Parse(encoded);
        Assert.Equal(0, parsed.Code);
        Assert.Empty(parsed.Payload);
    }

    [Fact]
    public void EncodeWithBuffer_ProducesSameResult()
    {
        var w = new WriteBuffer();
        w.WriteUint8(0xFF);
        var direct = SoulseekMessage.Encode(7, w.ToBytes());
        var viaBuffer = SoulseekMessage.EncodeWithBuffer(7, w);
        Assert.Equal(direct, viaBuffer);
    }

    [Fact]
    public void Parse_MalformedData_Throws()
    {
        var badData = new byte[] { 0, 0, 0 }; // too short
        Assert.Throws<BufferException>(() => SoulseekMessage.Parse(badData));
    }

    [Fact]
    public void Payload_IsReferenceEqual()
    {
        var payload = new byte[] { 1, 2, 3 };
        var msg = new SoulseekMessage(5, payload);
        Assert.Same(payload, msg.Payload);
    }

    [Fact]
    public void RecordStruct_Equality_UsesReferenceForPayload()
    {
        var payload = new byte[] { 1, 2 };
        var msg1 = new SoulseekMessage(1, payload);
        var msg2 = new SoulseekMessage(1, [1, 2]);
        // byte[] is compared by reference, so these should not be equal
        Assert.NotEqual(msg1, msg2);
    }
}