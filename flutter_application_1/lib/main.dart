import 'dart:convert';

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
    switch (name) {
      case '/':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const MyInitialScreen(),
        );
      case '/auth':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const MyAuthScreen(),
        );
      case '/chats':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const MyChatsScreen(),
        );
      default:
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

class MyAuthScreen extends StatefulWidget {
  const MyAuthScreen({super.key});

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
      Navigator.of(context).restorablePushReplacementNamed('/');
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
        Navigator.of(context).restorablePushReplacementNamed('/chats');
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).restorablePushReplacementNamed('/auth');
      }
    } else {
      if (!mounted) return;
      Navigator.of(context).restorablePushReplacementNamed('/auth');
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
      body: ListView(
        children: chats.values
            .map(
              (e) => ListTile(
                leading: e.avatar == null || e.avatar!.isEmpty
                    ? CircleAvatar(
                        child: Text('${e.id}'),
                      )
                    : Image.network(e.avatar!),
                title: Text('#${e.id}: ${e.name}'),
                subtitle: e.description == null ? null : Text(e.description!),
              ),
            )
            .toList(),
      ),
    );
  }
}
