import 'dart:developer';

import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:convas/common/otherClass/commonRtmChatChannelMessage.dart';
import 'package:convas/common/provider/userProvider.dart';
import 'package:convas/daoFirebase/appointmentsDaoFirebase.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtm/agora_rtm.dart';
import '../../callerCloudFunctions/callTokenGenerator.dart';
import '../../callerCloudFunctions/messageTokenGenerator.dart';
import '../../common/commonValues.dart';
import '../../common/otherClass/commonClassAppointment.dart';
import '../../common/provider/friendProvider.dart';
import '../../daoFirebase/chatDetailsDaoFirebase.dart';
import '../../entityIsar/friendEntityIsar.dart';
import '../../config/agora_config.dart' as config;

final callRoomProvider = ChangeNotifierProvider.autoDispose(
  (ref) => CallRoomNotifier(),
);

class CallRoomNotifier extends ChangeNotifier {
  AgoraRtmClient? _client;
  late final Friend _friendData;

  Friend get friendData => _friendData;
  late final CommonClassAppointment _appointmentData;

  CommonClassAppointment get appointmentData => _appointmentData;
  late final RtcEngine _engine;

  RtcEngine get engine => _engine;
  bool _isJoinedCall = false;
  bool get isJoinedCall => _isJoinedCall;
  bool _isJoinedClientMessage = false;

  bool get isJoinedMessage => _isJoinedClientMessage;
  bool _isJoinedChannelMessage = false;

  bool get isJoinedChannelMessage => _isJoinedChannelMessage;
  bool _switchCamera = true;

  bool get switchCamera => _switchCamera;
  bool _switchRender = true;

  bool get switchRender => _switchRender;
  int? _myUserid;

  int? get myUserid => _myUserid;
  bool _localVideoStatus = true;

  bool get localVideoStatus => _localVideoStatus;
  bool _localAvStatus = true;

  bool get localAvStatus => _localAvStatus;
  int? _friendUserid;

  int? get friendUserid => _friendUserid;
  List<CommonRtmChatChannelMessage> _channelMessageList = [];

  List<CommonRtmChatChannelMessage> get channelMessageList =>
      _channelMessageList;
  AgoraRtmChannel? _messageChannel;

  int _screenMode = 2;
  int get screenMode => _screenMode;

  Future<void> refleshAppointmentData()async {
    _appointmentData =
    await selectFirebaseAppointmentByAppointmentDocId(_appointmentData.appointmentDocId);
  }

  Future<void> initialize(String friendUserDocId, String appointmentDocId,
      WidgetRef ref) async {
    await updateAppointmentJoinedUser( ref, appointmentDocId,"callRoom");
    _screenMode = 2;
    _channelMessageList = [];
    _engine = await RtcEngine.createWithContext(RtcEngineContext(config.appId));
    addListeners();
    await _engine.enableVideo();
    await _engine.startPreview();
    await _engine.setChannelProfile(ChannelProfile.LiveBroadcasting);
    await _engine.setClientRole(ClientRole.Broadcaster);
    _localVideoStatus = true;
    _localAvStatus = true;


    _friendData = ref
        .watch(friendDataProvider)
        .friendData[friendUserDocId]!;
    _appointmentData =
    await selectFirebaseAppointmentByAppointmentDocId(appointmentDocId);

    await insertChatDetailsDataMessage(
        ref: ref,
        chatHeaderDocId: ref
            .watch(callRoomProvider)
            .friendData
            .chatHeaderId,
        friendUserDocId: friendUserDocId,
        message: enterRoomMessage,
        messageType: "1",
        referDocId: appointmentDocId,
        programId: "callRoom");


    if (_isJoinedCall == false) {
      await joinCallChannel();
    }

    if (_isJoinedClientMessage == false) {
      await joinClientMessage(ref);
    }

    if (_isJoinedChannelMessage == false) {
      await joinMessageChannel(ref);
    }
  }

  void changeScreenMode(){
    if(_screenMode==1){
      _screenMode=2;
    }else{
      _screenMode=1;
    }
    notifyListeners();
  }

  void addListeners() {
    _engine.setEventHandler(RtcEngineEventHandler(
      joinChannelSuccess: (channel, uid, elapsed) {
        log('joinChannelSuccess $channel $uid $elapsed');
        _isJoinedCall = true;
        notifyListeners();
      },
      userJoined: (uid, elapsed) {
        log('userJoined  $uid $elapsed');
        _friendUserid = uid;
        notifyListeners();
      },
      userOffline: (uid, reason) {
        log('userOffline  $uid $reason');
        _friendUserid = null;
        notifyListeners();
      },
      leaveChannel: (stats) {
        log('leaveChannel ${stats.toJson()}');
        _isJoinedCall = false;
        _myUserid = null;
        _friendUserid = null;
        notifyListeners();
      },
    ));
  }

  Future<void> joinCallChannel() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await [Permission.microphone, Permission.camera].request();
    }

    String tokenAndChannelId =
    await callTokenGenerator(_appointmentData.appointmentDocId);
    log("■■■■■■■■■■■■■■■■token:" + tokenAndChannelId);
    await _engine.joinChannel(
        tokenAndChannelId, _appointmentData.appointmentDocId, null, 0);
    notifyListeners();
  }

  Future<void> leaveChannel(WidgetRef ref, String appointmentDocId) async {
    await _engine.leaveChannel();
    await leaveMessageChannel(ref);
    await leaveClientMessage(ref);
    updateAppointmentDoneCall( ref, appointmentDocId, "callRoom");
    notifyListeners();
  }

  Future<void> changeAvMuteMode() async {
    _localAvStatus = !_localAvStatus;
    if (_localAvStatus) {
      await _engine.enableAudio();
    } else {
      await _engine.disableAudio();
    }

    notifyListeners();
  }

  Future<void> changeVideoMuteMode() async {
    _localVideoStatus = !_localVideoStatus;
    if (_localVideoStatus) {
      await _engine.enableVideo();
    } else {
      await _engine.disableVideo();
    }
    notifyListeners();
  }

  void changeSwitchCamera() {
    _engine.switchCamera().then((value) {
      _switchCamera = !_switchCamera;
    }).catchError((err) {
      log('switchCamera $err');
    });
  }

  Future<void> joinClientMessage(WidgetRef ref) async {
    _client = await AgoraRtmClient.createInstance(config.appId);
    _client?.onMessageReceived = (AgoraRtmMessage message, String peerId) {
      addMessage("send", message.text, ref);
    };

    _client?.onConnectionStateChanged = (int state, int reason) {
      log('Connection state changed: ' +
          state.toString() +
          ', reason: ' +
          reason.toString());
      if (state == 5) {
        _client?.logout();
        log('Logout.');
        _isJoinedClientMessage = false;
      }
    };
    // _client?.onLocalInvitationReceivedByPeer =
    //     (AgoraRtmLocalInvitation invite) {
    //   log('Local invitation received by peer: ${invite.calleeId}, content: ${invite.content}');
    // };
    // _client?.onRemoteInvitationReceivedByPeer =
    //     (AgoraRtmRemoteInvitation invite) {
    //   log('Remote invitation received by peer: ${invite.callerId}, content: ${invite.content}');
    // };

    String token = await messageTokenGenerator(ref
        .watch(userDataProvider)
        .userData["userDocId"]);

    await _client?.login(
        token, ref
        .watch(userDataProvider)
        .userData["userDocId"]);

    _isJoinedClientMessage = true;
  }

  void addMessage(String sendReceive, String textInfo, WidgetRef ref) {
    String userDocId = "";
    if (sendReceive == "send") {
      userDocId = ref
          .watch(userDataProvider)
          .userData["userDocId"];
    } else {
      userDocId = friendData.friendUserDocId;
    }

    CommonRtmChatChannelMessage tmpMessage = commonRtmChatChannelMessageMakeFromInfo(userDocId, textInfo, ref);
    _channelMessageList.insert(0,tmpMessage);
    notifyListeners();
  }

  void rebuildUI() {
    notifyListeners();
  }

  Future<void> leaveClientMessage(WidgetRef ref) async {
    try {
      await _client?.logout();
      addMessage("send", 'Logout success.', ref);

      _isJoinedClientMessage = false;
    } catch (errorCode) {
      log('Logout error: ' + errorCode.toString());
    }
  }

  Future<void> sendMessage(String textMessage, WidgetRef ref) async {
    String text = textMessage;
    if (text.isNotEmpty) {
      try {
        await _messageChannel?.sendMessage(AgoraRtmMessage.fromText(text));
        addMessage("send", text, ref);
      } catch (errorCode) {
        log('Send channel message error: ' + errorCode.toString());
      }
    }
  }

  Future<void> joinMessageChannel(WidgetRef ref) async {
    try {
      _messageChannel = await _createMessageChannel(_appointmentData.appointmentDocId + "message",ref);
      await _messageChannel?.join();
      addMessage("send", 'Join channel success.', ref);

      _isJoinedChannelMessage = true;
    } catch (errorCode) {
      log('Join channel error: ' + errorCode.toString());
    }
  }

  Future<void> leaveMessageChannel(WidgetRef ref) async {
    try {
      await _messageChannel?.leave();
      addMessage("send", 'leave channel success.', ref);
      if (_messageChannel != null) {
        _client?.releaseChannel(_messageChannel!.channelId!);
      }

      _isJoinedChannelMessage = false;
    } catch (errorCode) {
      log('Leave channel error: ' + errorCode.toString());
    }
  }

  Future<AgoraRtmChannel?> _createMessageChannel(String name,
      WidgetRef ref) async {
    AgoraRtmChannel? channel = await _client?.createChannel(name);
    if (channel != null) {
      channel.onMemberJoined = (AgoraRtmMember member) {
        addMessage("receive", 'Friend joined', ref);
        channel.onMemberLeft = (AgoraRtmMember member) {
          addMessage("receive", 'Friend left', ref);
        };
        channel.onMessageReceived =
            (AgoraRtmMessage message, AgoraRtmMember member) {
          addMessage("receive", message.text, ref);
        };
      };
      return channel;
    }
    return null;
  }
}
