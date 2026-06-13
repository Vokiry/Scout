using System.Text;

namespace Soulseek.Protocol.Messages;

public class WriteBuffer
{
    private readonly List<byte> _bytes = [];

    public void WriteUint8(byte value)
    {
        _bytes.Add(value);
    }

    public void WriteUint16(ushort value)
    {
        _bytes.Add((byte)(value & 0xFF));
        _bytes.Add((byte)((value >> 8) & 0xFF));
    }

    public void WriteUint32(uint value)
    {
        _bytes.Add((byte)(value & 0xFF));
        _bytes.Add((byte)((value >> 8) & 0xFF));
        _bytes.Add((byte)((value >> 16) & 0xFF));
        _bytes.Add((byte)((value >> 24) & 0xFF));
    }

    public void WriteUint64(ulong value)
    {
        for (int i = 0; i < 8; i++)
        {
            _bytes.Add((byte)(value & 0xFF));
            value >>= 8;
        }
    }

    public void WriteInt32(int value)
    {
        _bytes.Add((byte)(value & 0xFF));
        _bytes.Add((byte)((value >> 8) & 0xFF));
        _bytes.Add((byte)((value >> 16) & 0xFF));
        _bytes.Add((byte)((value >> 24) & 0xFF));
    }

    public void WriteBytes(byte[] bytes)
    {
        _bytes.AddRange(bytes);
    }

    public void WriteBytes(ReadOnlySpan<byte> bytes)
    {
        _bytes.AddRange(bytes);
    }

    public void WriteString(string value)
    {
        var encoded = Encoding.UTF8.GetBytes(value);
        WriteUint32((uint)encoded.Length);
        _bytes.AddRange(encoded);
    }

    public void WriteInt32Le(int value) => WriteInt32(value);

    public byte[] ToBytes() => _bytes.ToArray();
}