import 'package:flutter_application_1/src/chat_service.dart';
import 'package:surf_study_jam/surf_study_jam.dart';

void main(List<String> args) async {
  var client = StudyJamClient();
  client = client.getAuthorizedClient(token);
  final srvc = ChatService();
  await srvc.loadFromDisk();
  srvc.token = token;
  srvc.client = client;
  await srvc.refresh();
  await srvc.saveToDisk();
}
