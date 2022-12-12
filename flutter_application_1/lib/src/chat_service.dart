import 'dart:convert';
import 'dart:io';

import 'package:surf_study_jam/surf_study_jam.dart';

class ChatService {
  String? token;

  DateTime lastUpdateUsers = DateTime(2022);
  DateTime lastUpdateChats = DateTime(2022);
  DateTime lastUpdateMsgs = DateTime(2022);

  StudyJamClient client = StudyJamClient();
  SjUserDto? user;
  final users = <int, SjUserDto>{};
  final chats = <int, SjChatDto>{};
  final msgs = <int, Map<int, SjMessageDto>>{};

  static final tokenFile = File('token.txt');
  static final dataFile = File('data.json');
  Future<void> loadFromDisk() async {
    if (tokenFile.existsSync()) {
      final token = tokenFile.readAsStringSync().trim();
      this.token = token;
      client = StudyJamClient().getAuthorizedClient(token);
    }
    if (dataFile.existsSync()) {
      final data = jsonDecode(dataFile.readAsStringSync()) as Map;
      final lastUpdateUsers = data['lastUpdateUsers'] as String?;
      if (lastUpdateUsers != null) {
        this.lastUpdateUsers = DateTime.parse(lastUpdateUsers);
      }
      final lastUpdateChats = data['lastUpdateChats'] as String?;
      if (lastUpdateChats != null) {
        this.lastUpdateChats = DateTime.parse(lastUpdateChats);
      }
      final lastUpdateMsgs = data['lastUpdateMsgs'] as String?;
      if (lastUpdateMsgs != null) {
        this.lastUpdateMsgs = DateTime.parse(lastUpdateMsgs);
      }
      final users = data['users'] as Map?;
      if (users != null) {
        this.users.addAll(users.map((key, value) =>
            MapEntry(int.parse(key), SjUserDto.fromJson(value))));
      }
      final chats = data['chats'] as Map?;
      if (chats != null) {
        this.chats.addAll(chats.map((key, value) =>
            MapEntry(int.parse(key), SjChatDto.fromJson(value))));
      }
      final msgs = data['msgs'] as Map?;
      if (msgs != null) {
        this.msgs.addAll(msgs.map((key, value) => MapEntry(
            int.parse(key),
            (value as Map).map((key, value) =>
                MapEntry(int.parse(key), SjMessageDto.fromJson(value))))));
      }
    }
  }

  Future<void> saveToDisk() async {
    final token = this.token;
    if (token != null) tokenFile.writeAsStringSync(token);
    final data = <String, Object?>{};
    data['lastUpdateUsers'] = lastUpdateUsers.toIso8601String();
    data['lastUpdateChats'] = lastUpdateChats.toIso8601String();
    data['lastUpdateMsgs'] = lastUpdateMsgs.toIso8601String();
    data['users'] =
        users.map((key, value) => MapEntry(key.toString(), value.toJson()));
    data['chats'] =
        chats.map((key, value) => MapEntry(key.toString(), value.toJson()));
    data['msgs'] = msgs.map((key, value) => MapEntry(key.toString(),
        value.map((key, value) => MapEntry(key.toString(), value.toJson()))));
    dataFile.writeAsStringSync(jsonEncode(data));
  }

  Future<bool> refresh() async {
    final indexes = await client.getUpdates(
      users: lastUpdateUsers,
      msgs: lastUpdateMsgs,
      chats: lastUpdateChats,
    );
    var out = false;
    final usersI = indexes.users;
    if (usersI?.isNotEmpty ?? false) {
      usersI!;
      final users = await client.getUsers(usersI);
      for (final e in users) {
        this.users[e.id] = e;
      }
      out = true;
    }
    final chatsI = indexes.chats;
    if (chatsI?.isNotEmpty ?? false) {
      chatsI!;
      final chats = await client.getChatsByIds(chatsI);
      for (final e in chats) {
        this.chats[e.id] = e;
      }
      out = true;
    }
    final msgsI = indexes.msgs;
    if (msgsI?.isNotEmpty ?? false) {
      msgsI!;
      final msgs = await client
          .getMessagesByIds(msgsI.values.expand((element) => element).toList());
      for (final e in msgs) {
        (this.msgs[e.chatId] ??= {})[e.id] = e;
      }
      out = true;
    }
    return out;
  }

  Future<bool> isLogginned() async {
    try {
      final user = await client.getUser();
      this.user = user;
      return true;
    } catch (e) {
      print(e);
    }
    return false;
  }
}
