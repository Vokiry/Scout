using Soulseek.Protocol.Messages;
using Soulseek.Protocol.Peer;
using Soulseek.Protocol.Services;

namespace Soulseek.Protocol.Tests.Services;

public class BrowseServiceTests
{
    [Fact]
    public async Task BrowseUser_ReceivesReply()
    {
        var conn = new Transfer.MockTransferConnection("user1");
        var service = new BrowseService();

        SoulseekMessage? sent = null;
        conn.MessageSent += msg => sent = msg;

        var browseTask = service.BrowseUser(conn, "\\music");

        Assert.NotNull(sent);
        Assert.Equal(PeerCode.FolderContents, sent.Value.Code);

        // Send a reply
        var w = new WriteBuffer();
        w.WriteInt32(1);
        w.WriteString("\\music");
        w.WriteInt32(0);
        conn.SimulateMessage(PeerCode.FolderContentsReply, w.ToBytes());

        var result = await browseTask;
        Assert.Single(result.Folders);
        Assert.Equal("\\music", result.Folders[0].Path);
    }

    [Fact]
    public async Task BrowseUser_TimesOut_WhenNoReply()
    {
        var conn = new Transfer.MockTransferConnection("user1");
        var service = new BrowseService();

        await Assert.ThrowsAsync<TimeoutException>(async () =>
            await service.BrowseUser(conn, "", TimeSpan.FromMilliseconds(200)));
    }

    [Fact]
    public async Task BrowseUser_ConnectionDispose_FailsTask()
    {
        var conn = new Transfer.MockTransferConnection("user1");
        var service = new BrowseService();

        var browseTask = service.BrowseUser(conn, "");

        conn.Dispose();

        var ex = await Assert.ThrowsAsync<Exception>(async () => await browseTask);
        Assert.Contains("Connection closed", ex.Message);
    }

    [Fact]
    public async Task BrowseUser_IgnoresUnrelatedMessages()
    {
        var conn = new Transfer.MockTransferConnection("user1");
        var service = new BrowseService();

        var browseTask = service.BrowseUser(conn, "");

        // Send an unrelated message
        conn.SimulateMessage(PeerCode.TransferRequest, new WriteBuffer().ToBytes());

        // Verify the task is still pending
        await Task.Delay(50);
        Assert.False(browseTask.IsCompleted);
    }
}