using System.Buffers.Binary;
using System.Text;

namespace Soulseek.Protocol.Messages;

public class ReadBuffer
{
    private readonly byte[] _data;
    private int _offset;

    public ReadBuffer(byte[] data)
    {
        _data = data;
        _offset = 0;
    }

    public ReadBuffer(ReadOnlySpan<byte> data)
    {
        _data = data.ToArray();
        _offset = 0;
    }

    public int Offset => _offset;
    public int Remaining => _data.Length - _offset;
    public int Length => _data.Length;
    public bool IsEof => _offset >= _data.Length;

    public byte ReadUint8()
    {
        if (Remaining < 1) throw new BufferException("EOF while reading uint8");
        return _data[_offset++];
    }

    public ushort ReadUint16()
    {
        if (Remaining < 2) throw new BufferException("EOF while reading uint16");
        var value = BinaryPrimitives.ReadUInt16LittleEndian(_data.AsSpan(_offset, 2));
        _offset += 2;
        return value;
    }

    public uint ReadUint32()
    {
        if (Remaining < 4) throw new BufferException("EOF while reading uint32");
        var value = BinaryPrimitives.ReadUInt32LittleEndian(_data.AsSpan(_offset, 4));
        _offset += 4;
        return value;
    }

    public ulong ReadUint64()
    {
        if (Remaining < 8) throw new BufferException("EOF while reading uint64");
        var value = BinaryPrimitives.ReadUInt64LittleEndian(_data.AsSpan(_offset, 8));
        _offset += 8;
        return value;
    }

    public int ReadInt32()
    {
        if (Remaining < 4) throw new BufferException("EOF while reading int32");
        var value = BinaryPrimitives.ReadInt32LittleEndian(_data.AsSpan(_offset, 4));
        _offset += 4;
        return value;
    }

    public byte[] ReadBytes(int length)
    {
        if (Remaining < length) throw new BufferException("EOF while reading bytes");
        var bytes = new byte[length];
        Array.Copy(_data, _offset, bytes, 0, length);
        _offset += length;
        return bytes;
    }

    public string ReadString()
    {
        var length = ReadUint32();
        if (length == 0) return string.Empty;
        var bytes = ReadBytes((int)length);
        return Encoding.UTF8.GetString(bytes);
    }

    public byte[] ReadRemaining()
    {
        var bytes = new byte[Remaining];
        Array.Copy(_data, _offset, bytes, 0, Remaining);
        _offset = _data.Length;
        return bytes;
    }

    public int ReadInt32Le() => ReadInt32();
    public byte ReadByte() => ReadUint8();
}

public class BufferException : Exception
{
    public BufferException(string message) : base(message) { }
}