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
      case '/auth':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const MyAuthScreen(),
        );
      case '/':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const MyInitialScreen(),
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

class _MyAuthScreenState extends State<MyAuthScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();

  Future<void> submit() async {
    showDialog(
      context: context,
      builder: buildLoading,
      barrierDismissible: false,
    );
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

  Widget buildLoading(BuildContext context) {
    return WillPopScope(
      child: const Center(child: CircularProgressIndicator.adaptive()),
      onWillPop: () => SynchronousFuture(false),
    );
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

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
