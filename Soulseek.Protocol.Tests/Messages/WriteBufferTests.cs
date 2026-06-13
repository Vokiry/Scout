using Xunit;
using Soulseek.Protocol.Messages;

namespace Soulseek.Protocol.Tests.Messages;

public class WriteBufferTests
{
    [Fact]
    public void WriteUint8_WritesCorrectByte()
    {
        var w = new WriteBuffer();
        w.WriteUint8(0xAB);
        Assert.Equal([0xAB], w.ToBytes());
    }

    [Fact]
    public void WriteUint16_WritesLittleEndian()
    {
        var w = new WriteBuffer();
        w.WriteUint16(0x1234);
        Assert.Equal([0x34, 0x12], w.ToBytes());
    }

    [Fact]
    public void WriteUint32_WritesLittleEndian()
    {
        var w = new WriteBuffer();
        w.WriteUint32(0xDEADBEEF);
        Assert.Equal([0xEF, 0xBE, 0xAD, 0xDE], w.ToBytes());
    }

    [Fact]
    public void WriteUint64_WritesLittleEndian()
    {
        var w = new WriteBuffer();
        w.WriteUint64(0x0123456789ABCDEF);
        var bytes = w.ToBytes();
        Assert.Equal(8, bytes.Length);
        var result = BitConverter.ToUInt64(bytes);
        Assert.Equal(0x0123456789ABCDEFUL, result);
    }

    [Fact]
    public void WriteInt32_WritesCorrectValue()
    {
        var w = new WriteBuffer();
        w.WriteInt32(-1);
        var bytes = w.ToBytes();
        Assert.Equal(4, bytes.Length);
        Assert.Equal(-1, BitConverter.ToInt32(bytes));
    }

    [Fact]
    public void WriteString_WritesLengthPrefixedUtf8()
    {
        const string value = "test";
        var w = new WriteBuffer();
        w.WriteString(value);
        var bytes = w.ToBytes();
        Assert.Equal(4 + 4, bytes.Length);
        var length = BitConverter.ToUInt32(bytes);
        Assert.Equal(4u, length);
        var text = System.Text.Encoding.UTF8.GetString(bytes, 4, 4);
        Assert.Equal("test", text);
    }

    [Fact]
    public void WriteString_RoundTrip_WithReadBuffer()
    {
        const string original = "Hello, 世界!";
        var w = new WriteBuffer();
        w.WriteString(original);
        var r = new ReadBuffer(w.ToBytes());
        Assert.Equal(original, r.ReadString());
    }

    [Fact]
    public void WriteBytes_WritesAllBytes()
    {
        var w = new WriteBuffer();
        w.WriteBytes([1, 2, 3]);
        Assert.Equal([1, 2, 3], w.ToBytes());
    }

    [Fact]
    public void WriteBytes_Span_WritesAllBytes()
    {
        var w = new WriteBuffer();
        ReadOnlySpan<byte> span = [4, 5, 6];
        w.WriteBytes(span);
        Assert.Equal([4, 5, 6], w.ToBytes());
    }

    [Fact]
    public void WriteInt32Le_IsAliasForWriteInt32()
    {
        var w = new WriteBuffer();
        w.WriteInt32Le(42);
        var w2 = new WriteBuffer();
        w2.WriteInt32(42);
        Assert.Equal(w2.ToBytes(), w.ToBytes());
    }

    [Fact]
    public void ToBytes_ReturnsCopy()
    {
        var w = new WriteBuffer();
        w.WriteUint8(0xFF);
        var b1 = w.ToBytes();
        var b2 = w.ToBytes();
        Assert.Equal(b1, b2);
        Assert.NotSame(b1, b2);
    }

    [Fact]
    public void MultipleWrites_ProduceCorrectOutput()
    {
        var w = new WriteBuffer();
        w.WriteUint8(0x01);
        w.WriteUint16(0x0203);
        w.WriteUint32(0x04050607);
        w.WriteString("ab");

        var bytes = w.ToBytes();
        var r = new ReadBuffer(bytes);

        Assert.Equal(0x01, r.ReadUint8());
        Assert.Equal(0x0203, r.ReadUint16());
        Assert.Equal(0x04050607u, r.ReadUint32());
        Assert.Equal("ab", r.ReadString());
    }
}