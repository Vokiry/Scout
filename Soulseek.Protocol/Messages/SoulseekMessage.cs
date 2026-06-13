namespace Soulseek.Protocol.Messages;

public readonly record struct SoulseekMessage(int Code, byte[] Payload)
{
    public static SoulseekMessage Parse(byte[] data)
    {
        var buffer = new ReadBuffer(data);
        var length = buffer.ReadUint32();
        var code = (int)buffer.ReadUint32();
        var payload = buffer.ReadBytes((int)length - 4);
        return new SoulseekMessage(code, payload);
    }

    public static byte[] Encode(int code, byte[] payload)
    {
        var totalLength = 4 + payload.Length;
        var buffer = new WriteBuffer();
        buffer.WriteUint32((uint)totalLength);
        buffer.WriteUint32((uint)code);
        buffer.WriteBytes(payload);
        return buffer.ToBytes();
    }

    public static byte[] EncodeWithBuffer(int code, WriteBuffer payload)
    {
        return Encode(code, payload.ToBytes());
    }
}