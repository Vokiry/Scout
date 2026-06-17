using Xunit;
using Soulseek.Protocol.Messages;

namespace Soulseek.Protocol.Tests.Messages;

public class ReadBufferTests
{
    [Fact]
    public void ReadUint8_ValidData_ReturnsCorrectValue()
    {
        var data = new byte[] { 0x42 };
        var buffer = new ReadBuffer(data);
        Assert.Equal(0x42, buffer.ReadUint8());
        Assert.True(buffer.IsEof);
    }

    [Fact]
    public void ReadUint8_EmptyBuffer_Throws()
    {
        var buffer = new ReadBuffer([]);
        Assert.Throws<BufferException>(() => buffer.ReadUint8());
    }

    [Fact]
    public void ReadUint16_LittleEndian_ReturnsCorrectValue()
    {
        var data = new byte[] { 0x34, 0x12 };
        var buffer = new ReadBuffer(data);
        Assert.Equal(0x1234, buffer.ReadUint16());
    }

    [Fact]
    public void ReadUint32_LittleEndian_ReturnsCorrectValue()
    {
        var data = BitConverter.GetBytes(0xDEADBEEF);
        var buffer = new ReadBuffer(data);
        Assert.Equal(0xDEADBEEFu, buffer.ReadUint32());
    }

    [Fact]
    public void ReadUint64_LittleEndian_ReturnsCorrectValue()
    {
        var data = BitConverter.GetBytes(0x0123456789ABCDEFul);
        var buffer = new ReadBuffer(data);
        Assert.Equal(0x0123456789ABCDEFul, buffer.ReadUint64());
    }

    [Fact]
    public void ReadInt32_LittleEndian_ReturnsCorrectValue()
    {
        var data = BitConverter.GetBytes(-12345);
        var buffer = new ReadBuffer(data);
        Assert.Equal(-12345, buffer.ReadInt32());
    }

    [Fact]
    public void ReadString_ValidUtf8_ReturnsCorrectString()
    {
        const string expected = "Hello, Soulseek!";
        var encoded = System.Text.Encoding.UTF8.GetBytes(expected);
        var lengthPrefixed = new byte[4 + encoded.Length];
        BitConverter.GetBytes(encoded.Length).CopyTo(lengthPrefixed, 0);
        encoded.CopyTo(lengthPrefixed, 4);

        var buffer = new ReadBuffer(lengthPrefixed);
        Assert.Equal(expected, buffer.ReadString());
    }

    [Fact]
    public void ReadString_EmptyString_ReturnsEmpty()
    {
        var data = new byte[] { 0, 0, 0, 0 };
        var buffer = new ReadBuffer(data);
        Assert.Equal(string.Empty, buffer.ReadString());
    }

    [Fact]
    public void ReadBytes_ValidLength_ReturnsCorrectBytes()
    {
        var data = new byte[] { 1, 2, 3, 4, 5 };
        var buffer = new ReadBuffer(data);
        var result = buffer.ReadBytes(3);
        Assert.Equal([1, 2, 3], result);
        Assert.Equal(3, buffer.Offset);
    }

    [Fact]
    public void ReadBytes_InsufficientData_Throws()
    {
        var buffer = new ReadBuffer([1, 2]);
        Assert.Throws<BufferException>(() => buffer.ReadBytes(5));
    }

    [Fact]
    public void ReadRemaining_ReturnsAllUnreadBytes()
    {
        var data = new byte[] { 1, 2, 3, 4, 5 };
        var buffer = new ReadBuffer(data);
        buffer.ReadBytes(2);
        var remaining = buffer.ReadRemaining();
        Assert.Equal([3, 4, 5], remaining);
        Assert.True(buffer.IsEof);
    }

    [Fact]
    public void Offset_AdvancesCorrectly()
    {
        var data = new byte[20];
        data[0] = 0x01;
        var buffer = new ReadBuffer(data);
        Assert.Equal(0, buffer.Offset);
        buffer.ReadUint8();
        Assert.Equal(1, buffer.Offset);
        buffer.ReadUint32();
        Assert.Equal(5, buffer.Offset);
        buffer.ReadUint16();
        Assert.Equal(7, buffer.Offset);
    }

    [Fact]
    public void Remaining_ReturnsCorrectCount()
    {
        var buffer = new ReadBuffer([1, 2, 3, 4, 5]);
        Assert.Equal(5, buffer.Remaining);
        buffer.ReadBytes(2);
        Assert.Equal(3, buffer.Remaining);
    }

    [Fact]
    public void Length_ReturnsTotalDataLength()
    {
        var buffer = new ReadBuffer([1, 2, 3]);
        Assert.Equal(3, buffer.Length);
        buffer.ReadBytes(2);
        Assert.Equal(3, buffer.Length);
    }

    [Fact]
    public void IsEof_AfterReadingAllData_ReturnsTrue()
    {
        var buffer = new ReadBuffer([1, 2]);
        buffer.ReadBytes(2);
        Assert.True(buffer.IsEof);
    }

    [Fact]
    public void ReadInt32Le_IsAliasForReadInt32()
    {
        var data = BitConverter.GetBytes(9999);
        var buffer = new ReadBuffer(data);
        Assert.Equal(9999, buffer.ReadInt32Le());
    }

    [Fact]
    public void ReadByte_IsAliasForReadUint8()
    {
        var buffer = new ReadBuffer([0xAB]);
        Assert.Equal(0xAB, buffer.ReadByte());
    }

    [Fact]
    public void Constructor_FromSpan_CopiesData()
    {
        ReadOnlySpan<byte> span = [0x10, 0x20, 0x30];
        var buffer = new ReadBuffer(span);
        Assert.Equal(0x10, buffer.ReadByte());
        Assert.Equal(0x20, buffer.ReadByte());
        Assert.Equal(0x30, buffer.ReadByte());
    }
}