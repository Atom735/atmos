import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surf_study_jam/surf_study_jam.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Route? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '';
    if (name.startsWith(MyChat.routeNamePrefix)) {
      return MaterialPageRoute(
        settings: settings,
        builder: MyBuilderWrapper(MyChat(MyChat.routeNameChatId(name))).build,
      );
    }
    switch (name) {
      case MyInitialScreen.routeName:
        return MaterialPageRoute(
          settings: settings,
          builder: const MyBuilderWrapper(MyInitialScreen()).build,
        );
      case MyAuthScreen.routeName:
        return MaterialPageRoute(
          settings: settings,
          builder: const MyBuilderWrapper(MyAuthScreen()).build,
        );
      case MyChatsScreen.routeName:
        return MaterialPageRoute(
          settings: settings,
          builder: const MyBuilderWrapper(MyChatsScreen()).build,
        );
      default:
        debugger();
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SharedAppData(
      child: MaterialApp(
        theme: ThemeData.dark(),
        onGenerateRoute: onGenerateRoute,
      ),
    );
  }
}

class MyBuilderWrapper extends StatelessWidget {
  const MyBuilderWrapper(this.child, {super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class MyAuthScreen extends StatefulWidget {
  const MyAuthScreen({super.key});

  static const routeName = '/auth';

  @override
  State<MyAuthScreen> createState() => _MyAuthScreenState();
}

Widget _showLoadingDialogBuilder(BuildContext context) {
  return WillPopScope(
    child: const Center(child: CircularProgressIndicator.adaptive()),
    onWillPop: () => SynchronousFuture(false),
  );
}

Future<void> showLoadingDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: _showLoadingDialogBuilder,
    barrierDismissible: false,
  );
}

class _MyAuthScreenState extends State<MyAuthScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();

  Future<void> submit() async {
    showLoadingDialog(context);
    var complete = false;
    try {
      final token = await StudyJamClient().signin(_login.text, _password.text);
      final sp = await SharedPreferences.getInstance();
      await sp.setString('token', token);
      complete = true;
    } finally {
      Navigator.pop(context);
    }
    if (complete) {
      if (!mounted) return;
      Navigator.of(context)
          .restorablePushReplacementNamed(MyInitialScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    const pad = 16.0;
    return Scaffold(
      body: Form(
        child: Center(
          child: SizedBox(
            width: 312,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(pad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: pad),
                      child: TextFormField(
                        autofocus: true,
                        controller: _login,
                        autofillHints: const [AutofillHints.username],
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: pad),
                      child: TextFormField(
                        controller: _password,
                        autofillHints: const [AutofillHints.password],
                        keyboardType: TextInputType.visiblePassword,
                        obscureText: true,
                        textInputAction: TextInputAction.send,
                        onEditingComplete: submit,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(pad),
                      child: TextButton(
                        onPressed: submit,
                        child: const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyInitialScreen extends StatefulWidget {
  const MyInitialScreen({super.key});

  static const routeName = Navigator.defaultRouteName;

  @override
  State<MyInitialScreen> createState() => _MyInitialScreenState();
}

class _MyInitialScreenState extends State<MyInitialScreen> {
  var initial = true;

  @override
  void didChangeDependencies() {
    if (initial) {
      initial = false;
      checkTokenData();
    }
    super.didChangeDependencies();
  }

  Future<void> checkTokenData() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token');
    if (token != null) {
      try {
        final client = StudyJamClient().getAuthorizedClient(token);
        final user = await client.getUser();
        user!;
        if (!mounted) return;
        SharedAppData.setValue(context, SjUserDto, user);
        SharedAppData.setValue(context, StudyJamClient, client);
        Navigator.of(context)
            .restorablePushReplacementNamed(MyChatsScreen.routeName);
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context)
            .restorablePushReplacementNamed(MyAuthScreen.routeName);
      }
    } else {
      if (!mounted) return;
      Navigator.of(context)
          .restorablePushReplacementNamed(MyAuthScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator.adaptive(),
      ),
    );
  }
}

class MyChatsScreen extends StatefulWidget {
  const MyChatsScreen({super.key});

  static const routeName = '/chats';

  @override
  State<MyChatsScreen> createState() => _MyChatsScreenState();
}

class _MyChatsScreenState extends State<MyChatsScreen> {
  var lastUpdateChats = DateTime(2022);

  late final client = SharedAppData.getValue<Type, StudyJamClient>(
    context,
    StudyJamClient,
    () => StudyJamClient(),
  );

  final chats = <int, SjChatDto>{};

  var initial = true;
  @override
  void didChangeDependencies() {
    if (initial) {
      initial = false;
      loadData();
    }
    super.didChangeDependencies();
  }

  Future<void> loadData() async {
    await Future.delayed(const Duration(microseconds: 1));
    if (!mounted) return;
    showLoadingDialog(context);
    try {
      final sp = await SharedPreferences.getInstance();
      lastUpdateChats = DateTime.parse(
        sp.getString('lastUpdateChats') ?? DateTime(2022).toIso8601String(),
      );
      final chats = jsonDecode(sp.getString('chats') ?? '{}') as Map?;
      if (chats != null) {
        this.chats.addAll(chats.map((key, value) =>
            MapEntry(int.parse(key), SjChatDto.fromJson(value))));
      }
    } finally {
      Navigator.pop(context);
    }
    await refresh();
  }

  Future<void> refresh() async {
    showLoadingDialog(context);
    try {
      final sp = await SharedPreferences.getInstance();

      final indexes = await client.getUpdates(
        chats: lastUpdateChats,
      );

      final chatsI = indexes.chats;
      if (chatsI?.isNotEmpty ?? false) {
        chatsI!;
        final l = ((chatsI.length - 1) ~/ 1000) + 1;
        for (var i = 0; i < l; i++) {
          final chats = await client.getChatsByIds(
            chatsI.skip(i * 1000).take(1000).toList(),
          );
          for (final e in chats) {
            if (e.updated.isAfter(lastUpdateChats)) {
              lastUpdateChats = e.updated;
            }
            this.chats[e.id] = e;
          }
        }
        setState(() {});
      }

      await sp.setString('lastUpdateChats', lastUpdateChats.toIso8601String());
      final chats = this.chats.map(
            (key, value) => MapEntry(key.toString(), value.toJson()),
          );
      await sp.setString('chats', jsonEncode(chats));
    } finally {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),
      body: ListView(
        children: chats.values.map(MyChatPreviewListTile.new).toList(),
      ),
    );
  }
}

class MyChatPreviewListTile extends StatelessWidget {
  MyChatPreviewListTile(this.e, {Key? key}) : super(key: key ?? ValueKey(e.id));

  final SjChatDto e;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(
          e.avatar ??
              'https://raw.githubusercontent.com/julien-gargot/images-placeholder/master/placeholder-square.png',
        ),
      ),
      title: Text('#${e.id}: ${e.name}'),
      subtitle: e.description == null ? null : Text(e.description!),
      onTap: () {
        Navigator.of(context).restorablePushNamed(MyChat.routeName(e.id));
      },
    );
  }
}

class MyChat extends StatefulWidget {
  MyChat(this.chatId, {Key? key}) : super(key: key ?? ValueKey(chatId));

  final int chatId;

  static const routeNamePrefix = '/chat/';
  static String routeName(int chatId) => '$routeNamePrefix$chatId';
  static int routeNameChatId(String routeName) =>
      int.parse(routeName.substring(routeNamePrefix.length));

  @override
  State<MyChat> createState() => _MyChatState();
}

class _MyChatState extends State<MyChat> {
  int get chatId => widget.chatId;

  var lastUpdateMsgs = DateTime(2022);

  SjChatDto? chat;

  late final client = SharedAppData.getValue<Type, StudyJamClient>(
    context,
    StudyJamClient,
    () => StudyJamClient(),
  );

  final msgs = <int, SjMessageDto>{};

  var initial = true;
  @override
  void didChangeDependencies() {
    if (initial) {
      initial = false;
      loadData();
    }
    super.didChangeDependencies();
  }

  Future<void> loadData() async {
    await Future.delayed(const Duration(microseconds: 1));
    if (!mounted) return;
    showLoadingDialog(context);
    try {
      final sp = await SharedPreferences.getInstance();
      lastUpdateMsgs = DateTime.parse(
        sp.getString('lastUpdateMsgs/$chatId') ??
            DateTime(2022).toIso8601String(),
      );
      final msgs = jsonDecode(sp.getString('msgs/$chatId') ?? '{}') as Map?;
      if (msgs != null) {
        this.msgs.addAll(msgs.map((key, value) =>
            MapEntry(int.parse(key), SjMessageDto.fromJson(value))));
      }
    } finally {
      Navigator.pop(context);
    }
    await refresh();
  }

  Future<void> refresh() async {
    showLoadingDialog(context);
    try {
      final sp = await SharedPreferences.getInstance();

      final indexes = await client.getUpdates(
        msgs: lastUpdateMsgs,
      );
      final chats = (await client.getChatsByIds([chatId]));
      if (chats.isNotEmpty) chat = chats.single;

      final msgsI = indexes.msgs?[chatId];
      if (msgsI?.isNotEmpty ?? false) {
        msgsI!;
        final l = ((msgsI.length - 1) ~/ 1000) + 1;
        for (var i = 0; i < l; i++) {
          final msgs = await client.getMessagesByIds(
            msgsI.skip(i * 1000).take(1000).toList(),
          );
          for (final e in msgs) {
            if (e.updated.isAfter(lastUpdateMsgs)) {
              lastUpdateMsgs = e.updated;
            }
            this.msgs[e.id] = e;
          }
        }
        refreshItemsInListView();
      }

      await sp.setString(
          'lastUpdateMsgs/$chatId', lastUpdateMsgs.toIso8601String());
      final msgs = this.msgs.map(
            (key, value) => MapEntry(key.toString(), value.toJson()),
          );
      await sp.setString('msgs/$chatId', jsonEncode(msgs));
    } finally {
      Navigator.pop(context);
    }
  }

  int itemsCount = 0;
  List<SjMessageDto> items = [];
  Widget itemBuilderFunc(BuildContext context, int index) {
    return MyMsgListTile(items[index]);
  }

  void refreshItemsInListView() {
    itemBuilder =
        (BuildContext context, int index) => itemBuilderFunc(context, index);
    itemsCount = msgs.length;
    items = msgs.values.toList()..sort((a, b) => b.id.compareTo(a.id));
    setState(() {});
  }

  late IndexedWidgetBuilder itemBuilder = itemBuilderFunc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(chat?.name ?? 'Unnamed')),
      body: ListView.builder(
        itemBuilder: itemBuilder,
        itemCount: itemsCount,
        reverse: true,
      ),
    );
  }
}

class MyMsgListTile extends StatelessWidget {
  MyMsgListTile(this.e, {Key? key}) : super(key: key ?? ValueKey(e.id));

  final SjMessageDto e;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('#${e.id}: ${e.updated}'),
      subtitle: Text(e.text ?? ''),
    );
  }
}
