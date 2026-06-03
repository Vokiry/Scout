// Soulseek message codes
// Based on Nicotine+ SLSKPROTOCOL.md specification

class ServerCode {
  ServerCode._();

  static const int login = 1;
  static const int setListenPort = 2;
  static const int getPeerAddress = 3;
  static const int addUser = 5;
  static const int parentInactivityTimeout = 8;
  static const int parentMinSpeed = 9;
  static const int searchRequest = 26;
  static const int searchResponse = 28;
  static const int userExists = 34;
  static const int userExistsResponse = 35;
  static const int getStatus = 36;
  static const int statusResponse = 37;
  static const int ping = 40;
  static const int pong = 41;
  static const int joinRoom = 43;
  static const int leaveRoom = 44;
  static const int userJoinedRoom = 45;
  static const int userLeftRoom = 46;
  static const int roomMessage = 47;
  static const int roomList = 48;
  static const int privateMessage = 51;
  static const int privateMessageACK = 52;
  static const int acknowledgeNotifyACL = 53;
  static const int notifyACL = 54;
  static const int serverShuttingDown = 55;
  static const int checkPrivileges = 56;
  static const int privilegesResponse = 57;
  static const int checkDownloadQueue = 58;
  static const int checkDownloadQueueResp = 59;
  static const int userSearchResponse = 60;
  static const int addPrivilegedUser = 61;
  static const int removePrivilegedUser = 62;
  static const int acceptPrivilegedUser = 63;
  static const int placeInQueueResponse = 64;
  static const int parentPathMerge = 65;
  static const int parentPathAlias = 66;
  static const int wishes = 67;
  static const int wishReply = 68;
  static const int wishlistInclusion = 69;
  static const int configuration = 100;
  static const int distributedAliveInterval = 102;
  static const int addThing = 110;
  static const int removeThing = 111;
  static const int thingsAtPlace = 112;
  static const int thingsAtPlaceReply = 113;
  static const int thingGroups = 114;
  static const int thingGroupsReply = 115;
  static const int placeGroups = 116;
  static const int placeGroupsReply = 117;
  static const int fileSearch = 120;
  static const int fileSearchReply = 121;
  static const int suggestSimilar = 122;
  static const int similarUsers = 123;
  static const int similarUsersReply = 124;
  static const int comments = 125;
  static const int commentsReply = 126;
  static const int itemFolder = 127;
  static const int itemFolderReply = 128;
  static const int itemPath = 129;
  static const int itemPathReply = 130;
  static const int folderContents = 131;
  static const int folderContentsReply = 132;
  static const int userPrivileges = 133;
  static const int userPrivilegesReply = 134;
  static const int privateRoomUsers = 135;
  static const int privateRoomUsersReply = 136;
  static const int privateRoomAddUser = 137;
  static const int privateRoomRemoveUser = 138;
  static const int privateRoomDismember = 139;
  static const int privateRoomToggle = 140;
  static const int privateRoomAdded = 141;
  static const int privateRoomRemoved = 142;
  static const int privateRoomDismembered = 143;
  static const int privateRoomOwners = 144;
  static const int privateRoomOwnersReply = 145;
  static const int similarEntry = 146;
  static const int similarEntryReply = 147;
  static const int roomTickers = 148;
  static const int roomTickersReply = 149;
  static const int roomTickerSet = 150;
  static const int roomTickerRemove = 151;
  static const int roomSearch = 152;
  static const int sendUploadSpeed = 153;
  static const int userStats = 154;
  static const int userStatsReply = 155;
  static const int privateRoomAddPrivilegedUser = 156;
  static const int privateRoomRemovePrivilegedUser = 157;
  static const int privateRoomACL = 158;
  static const int privateRoomACLReply = 159;
  static const int accountNotify = 160;
  static const int embeddedMessage = 161;
  static const int acceptChildren = 162;
  static const int interestAdd = 163;
  static const int interestRemove = 164;
  static const int interestReply = 165;
  static const int adminMessage = 166;
  static const int globalMessage = 167;
  static const int recommendedFileSearch = 168;
  static const int searchRequestSocial = 169;
  static const int searchParent = 170;
  static const int searchChild = 171;
  static const int killParentSearch = 172;
  static const int killChildSearch = 173;
  static const int addDistributedChild = 174;
  static const int removeDistributedChild = 175;
  static const int addDistributedParent = 176;
  static const int removeDistributedParent = 177;
  static const int branchLevel = 178;
  static const int branchRoot = 179;
  static const int childDepth = 180;
  static const int distributedSearch = 181;
  static const int compressedSearch = 182;
  static const int degradedSearch = 183;
  static const int loginResponse = 206;
  static const int changePassword = 207;
  static const int newPassword = 208;
  static const int kickMessage = 209;
  static const int banMessage = 210;
  static const int setListenPort2 = 211;
  static const int messageUsers = 212;
  static const int messageUsersReply = 213;
  static const int privateRoomSearch = 214;
  static const int privateRoomSearchReply = 215;
}

class PeerCode {
  PeerCode._();

  static const int fileSearch = 120;
  static const int fileSearchReply = 121;
  static const int folderContents = 131;
  static const int folderContentsReply = 132;
  static const int userInfo = 133;
  static const int userInfoReply = 134;
  static const int transferRequest = 135;
  static const int transferResponse = 136;
  static const int placehold = 137;
  static const int queueFailed = 138;
  static const int placeInQueue = 139;
  static const int uploadFailed = 140;
  static const int queueUpload = 141;
  static const int placeInQueueResponse = 142;
  static const int uploadDenied = 143;
  static const int userPrivileges = 144;
  static const int userPrivilegesReply = 145;
  static const int searchResponse = 147;
  static const int infoRequest = 148;
  static const int infoReply = 149;
  static const int folderSearch = 150;
  static const int folderSearchReply = 151;
}

class DistantCode {
  DistantCode._();

  static const int fileSearch = 3;
  static const int fileSearchReply = 4;
}

class Direction {
  Direction._();

  static const int download = 0;
  static const int upload = 1;
}
