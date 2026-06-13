namespace Soulseek.Protocol.Messages;

public static class ServerCode
{
    public const int Login = 1;
    public const int SetListenPort = 2;
    public const int GetPeerAddress = 3;
    public const int AddUser = 5;
    public const int ParentInactivityTimeout = 8;
    public const int ParentMinSpeed = 9;
    public const int SearchRequest = 26;
    public const int SearchResponse = 28;
    public const int UserExists = 34;
    public const int UserExistsResponse = 35;
    public const int GetStatus = 36;
    public const int StatusResponse = 37;
    public const int Ping = 40;
    public const int Pong = 41;
    public const int JoinRoom = 43;
    public const int LeaveRoom = 44;
    public const int UserJoinedRoom = 45;
    public const int UserLeftRoom = 46;
    public const int RoomMessage = 47;
    public const int RoomList = 48;
    public const int PrivateMessage = 51;
    public const int PrivateMessageAck = 52;
    public const int AcknowledgeNotifyAcl = 53;
    public const int NotifyAcl = 54;
    public const int ServerShuttingDown = 55;
    public const int CheckPrivileges = 56;
    public const int PrivilegesResponse = 57;
    public const int CheckDownloadQueue = 58;
    public const int CheckDownloadQueueResp = 59;
    public const int UserSearchResponse = 60;
    public const int AddPrivilegedUser = 61;
    public const int RemovePrivilegedUser = 62;
    public const int AcceptPrivilegedUser = 63;
    public const int PlaceInQueueResponse = 64;
    public const int ParentPathMerge = 65;
    public const int ParentPathAlias = 66;
    public const int Wishes = 67;
    public const int WishReply = 68;
    public const int WishlistInclusion = 69;
    public const int Configuration = 100;
    public const int DistributedAliveInterval = 102;
    public const int AddThing = 110;
    public const int RemoveThing = 111;
    public const int ThingsAtPlace = 112;
    public const int ThingsAtPlaceReply = 113;
    public const int ThingGroups = 114;
    public const int ThingGroupsReply = 115;
    public const int PlaceGroups = 116;
    public const int PlaceGroupsReply = 117;
    public const int FileSearch = 120;
    public const int FileSearchReply = 121;
    public const int SuggestSimilar = 122;
    public const int SimilarUsers = 123;
    public const int SimilarUsersReply = 124;
    public const int Comments = 125;
    public const int CommentsReply = 126;
    public const int ItemFolder = 127;
    public const int ItemFolderReply = 128;
    public const int ItemPath = 129;
    public const int ItemPathReply = 130;
    public const int FolderContents = 131;
    public const int FolderContentsReply = 132;
    public const int UserPrivileges = 133;
    public const int UserPrivilegesReply = 134;
    public const int PrivateRoomUsers = 135;
    public const int PrivateRoomUsersReply = 136;
    public const int PrivateRoomAddUser = 137;
    public const int PrivateRoomRemoveUser = 138;
    public const int PrivateRoomDismember = 139;
    public const int PrivateRoomToggle = 140;
    public const int PrivateRoomAdded = 141;
    public const int PrivateRoomRemoved = 142;
    public const int PrivateRoomDismembered = 143;
    public const int PrivateRoomOwners = 144;
    public const int PrivateRoomOwnersReply = 145;
    public const int SimilarEntry = 146;
    public const int SimilarEntryReply = 147;
    public const int RoomTickers = 148;
    public const int RoomTickersReply = 149;
    public const int RoomTickerSet = 150;
    public const int RoomTickerRemove = 151;
    public const int RoomSearch = 152;
    public const int SendUploadSpeed = 153;
    public const int UserStats = 154;
    public const int UserStatsReply = 155;
    public const int PrivateRoomAddPrivilegedUser = 156;
    public const int PrivateRoomRemovePrivilegedUser = 157;
    public const int PrivateRoomAcl = 158;
    public const int PrivateRoomAclReply = 159;
    public const int AccountNotify = 160;
    public const int EmbeddedMessage = 161;
    public const int AcceptChildren = 162;
    public const int InterestAdd = 163;
    public const int InterestRemove = 164;
    public const int InterestReply = 165;
    public const int AdminMessage = 166;
    public const int GlobalMessage = 167;
    public const int RecommendedFileSearch = 168;
    public const int SearchRequestSocial = 169;
    public const int SearchParent = 170;
    public const int SearchChild = 171;
    public const int KillParentSearch = 172;
    public const int KillChildSearch = 173;
    public const int AddDistributedChild = 174;
    public const int RemoveDistributedChild = 175;
    public const int AddDistributedParent = 176;
    public const int RemoveDistributedParent = 177;
    public const int BranchLevel = 178;
    public const int BranchRoot = 179;
    public const int ChildDepth = 180;
    public const int DistributedSearch = 181;
    public const int CompressedSearch = 182;
    public const int DegradedSearch = 183;
    public const int LoginResponse = 206;
    public const int ChangePassword = 207;
    public const int NewPassword = 208;
    public const int KickMessage = 209;
    public const int BanMessage = 210;
    public const int SetListenPort2 = 211;
    public const int MessageUsers = 212;
    public const int MessageUsersReply = 213;
    public const int PrivateRoomSearch = 214;
    public const int PrivateRoomSearchReply = 215;
}

public static class PeerCode
{
    public const int FileSearch = 120;
    public const int FileSearchReply = 121;
    public const int FolderContents = 131;
    public const int FolderContentsReply = 132;
    public const int UserInfo = 133;
    public const int UserInfoReply = 134;
    public const int TransferRequest = 135;
    public const int TransferResponse = 136;
    public const int Placehold = 137;
    public const int QueueFailed = 138;
    public const int PlaceInQueue = 139;
    public const int UploadFailed = 140;
    public const int QueueUpload = 141;
    public const int PlaceInQueueResponse = 142;
    public const int UploadDenied = 143;
    public const int UserPrivileges = 144;
    public const int UserPrivilegesReply = 145;
    public const int SearchResponse = 147;
    public const int InfoRequest = 148;
    public const int InfoReply = 149;
    public const int FolderSearch = 150;
    public const int FolderSearchReply = 151;
}

public static class DistantCode
{
    public const int FileSearch = 3;
    public const int FileSearchReply = 4;
}

public static class Direction
{
    public const int Download = 0;
    public const int Upload = 1;
}