```dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nexus AI - Offline / No Backend Version
///
/// This version:
/// - Does not connect to a backend
/// - Does not require authentication
/// - Keeps chat history locally
/// - Allows local file selection
/// - Keeps the existing main navigation
/// - Provides local/demo AI responses
///
/// No API_URL or backend server is required.

class DebugLog {
  static final List<String> entries = [];
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static void add(String message) {
    final line =
        '[${DateTime.now().toIso8601String().substring(11, 19)}] $message';

    entries.add(line);

    if (entries.length > 300) {
      entries.removeAt(0);
    }

    debugPrint(line);
    version.value++;
  }

  static void error(
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    add('ERROR: $message');

    if (error != null) {
      add('DETAIL: $error');
    }

    if (stack != null) {
      debugPrintStack(stackTrace: stack);
    }
  }

  static void clear() {
    entries.clear();
    version.value++;
  }
}

class DebugConsolePage extends StatelessWidget {
  const DebugConsolePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nexus AI Debug Console'),
        actions: [
          IconButton(
            tooltip: 'Clear logs',
            onPressed: DebugLog.clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: DebugLog.version,
        builder: (_, __, ___) {
          if (DebugLog.entries.isEmpty) {
            return const Center(
              child: Text('No runtime logs yet.'),
            );
          }

          return SelectionArea(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: DebugLog.entries.length,
              itemBuilder: (_, i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    DebugLog.entries[i],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Local application storage.
///
/// Nothing is sent to a server.
class LocalStorage {
  static const String chatKey = 'offline_messages';
  static const String filesKey = 'offline_files';

  static Future<List<Map<String, dynamic>>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(chatKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      }
    } catch (e) {
      DebugLog.error(
        'Could not load local messages.',
        e,
      );
    }

    return [];
  }

  static Future<void> saveMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      chatKey,
      jsonEncode(messages),
    );
  }

  static Future<List<String>> loadFiles() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getStringList(filesKey) ?? [];
  }

  static Future<void> saveFiles(
    List<String> files,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      filesKey,
      files,
    );
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(chatKey);
    await prefs.remove(filesKey);
  }
}

/// Local AI/demo engine.
///
/// This deliberately does not make an HTTP request.
class LocalAI {
  static String generateReply(String message) {
    final text = message.trim().toLowerCase();

    if (text.isEmpty) {
      return 'Please enter a message.';
    }

    if (text.contains('hello') ||
        text.contains('hi') ||
        text.contains('hey')) {
      return 'Hello! I am Nexus AI running in offline mode. '
          'No backend connection is required.';
    }

    if (text.contains('who are you') ||
        text.contains('what are you')) {
      return 'I am Nexus AI running in local demo mode. '
          'The current version does not use a backend server.';
    }

    if (text.contains('backend')) {
      return 'The backend is disabled in this version. '
          'Chat responses are generated locally for testing the app UI.';
    }

    if (text.contains('help')) {
      return 'I can help you test the Nexus AI interface, '
          'navigation, local chat history, and file selection.';
    }

    if (text.contains('thank')) {
      return 'You are welcome!';
    }

    if (text.contains('time')) {
      final now = DateTime.now();

      return 'Your device time is '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}.';
    }

    return 'Offline demo response:\n\n'
        'I received your message:\n'
        '"$message"\n\n'
        'The Nexus AI backend is currently disabled, so this '
        'response was generated locally.';
  }
}

/// Local file manager.
///
/// Files are NOT uploaded anywhere.
class LocalFiles {
  static Future<String?> pickFile() async {
    DebugLog.add('Opening local file picker...');

    final result = await FilePicker.platform.pickFiles(
      withData: false,
    );

    if (result == null) {
      DebugLog.add('File picker cancelled.');
      return null;
    }

    final file = result.files.single;

    DebugLog.add(
      'Selected local file: ${file.name}',
    );

    final files = await LocalStorage.loadFiles();

    if (!files.contains(file.name)) {
      files.add(file.name);
      await LocalStorage.saveFiles(files);
    }

    return file.name;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (
    FlutterErrorDetails details,
  ) {
    FlutterError.presentError(details);

    DebugLog.error(
      'Flutter framework error',
      details.exception,
      details.stack,
    );
  };

  ui.PlatformDispatcher.instance.onError =
      (Object error, StackTrace stack) {
    DebugLog.error(
      'Uncaught asynchronous error',
      error,
      stack,
    );

    return true;
  };

  DebugLog.add('Nexus AI started.');
  DebugLog.add('OFFLINE MODE enabled.');
  DebugLog.add('Backend connection disabled.');
  DebugLog.add('Authentication disabled.');

  runApp(
    const App(),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nexus AI',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),

      // Directly open Home.
      //
      // No Login screen.
      home: const Home(),
    );
  }
}

/// Kept in the project as a page, but it is no longer required.
class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_open,
                  size: 56,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Authentication Disabled',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This offline version does not require '
                  'authentication.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Home(),
                      ),
                    );
                  },
                  child: const Text('Open Nexus AI'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int page = 0;

  List<Map<String, dynamic>> msgs = [];

  List<String> files = [];

  final input = TextEditingController();

  bool loading = false;

  final labels = [
    'Chats',
    'Projects',
    'Files',
    'Agents',
    'Research',
    'Images',
    'Settings',
  ];

  final icons = [
    Icons.chat,
    Icons.folder,
    Icons.description,
    Icons.smart_toy,
    Icons.search,
    Icons.image,
    Icons.settings,
  ];

  @override
  void initState() {
    super.initState();

    loadLocalData();
  }

  Future<void> loadLocalData() async {
    DebugLog.add(
      'Loading local application data...',
    );

    final savedMessages =
        await LocalStorage.loadMessages();

    final savedFiles =
        await LocalStorage.loadFiles();

    if (!mounted) return;

    setState(() {
      msgs = savedMessages;
      files = savedFiles;
    });

    DebugLog.add(
      'Local data loaded: '
      '${msgs.length} messages, '
      '${files.length} files.',
    );
  }

  Future<void> send() async {
    final text = input.text.trim();

    if (text.isEmpty || loading) {
      return;
    }

    input.clear();

    setState(() {
      loading = true;

      msgs.add({
        'role': 'user',
        'content': text,
      });
    });

    await LocalStorage.saveMessages(msgs);

    DebugLog.add(
      'Local message added.',
    );

    // Small delay to make the UI feel like an AI response.
    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    final reply = LocalAI.generateReply(text);

    if (!mounted) return;

    setState(() {
      msgs.add({
        'role': 'assistant',
        'content': reply,
      });

      loading = false;
    });

    await LocalStorage.saveMessages(msgs);

    DebugLog.add(
      'Local AI response generated.',
    );
  }

  Future<void> attachFile() async {
    try {
      final name = await LocalFiles.pickFile();

      if (name == null || !mounted) {
        return;
      }

      setState(() {
        if (!files.contains(name)) {
          files.add(name);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'File added locally: $name',
          ),
        ),
      );

      DebugLog.add(
        'File stored locally: $name',
      );
    } catch (e, st) {
      DebugLog.error(
        'Local file selection failed',
        e,
        st,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not select file: $e',
          ),
        ),
      );
    }
  }

  Future<void> clearChat() async {
    setState(() {
      msgs.clear();
    });

    await LocalStorage.saveMessages(msgs);

    DebugLog.add(
      'Local chat history cleared.',
    );
  }

  Future<void> clearLocalData() async {
    await LocalStorage.clearAll();

    if (!mounted) return;

    setState(() {
      msgs.clear();
      files.clear();
    });

    DebugLog.add(
      'All local data cleared.',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Local data cleared.',
        ),
      ),
    );
  }

  Widget chat() {
    return Column(
      children: [
        Expanded(
          child: msgs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'What can I help you with today?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Nexus AI is running in offline mode.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final message = msgs[index];

                    final isUser =
                        message['role'] == 'user';

                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(
                          bottom: 12,
                        ),
                        padding: const EdgeInsets.all(14),
                        constraints:
                            const BoxConstraints(
                          maxWidth: 700,
                        ),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(16),
                          color: isUser
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                        ),
                        child: Text(
                          message['content']
                              ?.toString() ??
                              '',
                        ),
                      ),
                    );
                  },
                ),
        ),

        if (loading)
          const Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: 8,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('Thinking...'),
                ],
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Attach local file',
                onPressed:
                    loading ? null : attachFile,
                icon: const Icon(
                  Icons.attach_file,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: input,
                  onSubmitted: (_) => send(),
                  minLines: 1,
                  maxLines: 5,
                  decoration:
                      const InputDecoration(
                    hintText: 'Ask anything...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send',
                onPressed:
                    loading ? null : send,
                icon: const Icon(
                  Icons.send,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget projects() {
    return _modulePage(
      icon: Icons.folder,
      title: 'Projects',
      description:
          'Projects are available in offline demo mode.',
      child: FilledButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Project creation is running locally.',
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Project'),
      ),
    );
  }

  Widget filesPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Files',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Files selected here stay on this device. '
            'They are not uploaded to a backend.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: attachFile,
            icon: const Icon(
              Icons.upload_file,
            ),
            label: const Text(
              'Select Local File',
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: files.isEmpty
                ? const Center(
                    child: Text(
                      'No local files selected.',
                    ),
                  )
                : ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (_, index) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.insert_drive_file,
                          ),
                          title: Text(
                            files[index],
                          ),
                          subtitle:
                              const Text(
                            'Stored locally',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget agents() {
    return _modulePage(
      icon: Icons.smart_toy,
      title: 'Agents',
      description:
          'Agent interface is available without a backend.',
      child: FilledButton(
        onPressed: () {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Agent execution requires a backend or AI provider.',
              ),
            ),
          );
        },
       ialized();

  FlutterError.onError = (
    FlutterErrorDetails details,
  ) {
    FlutterError.presentError(details);

    DebugLog.error(
      'Flutter framework error',
      details.exception,
      details.stack,
    );
  };

  ui.PlatformDispatcher.instance.onError =
      (Object error, StackTrace stack) {
    DebugLog.error(
      'Uncaught asynchronous error',
      error,
      stack,
    );

    return true;
  };

  DebugLog.add(
    'Nexus AI started.',
  );

  DebugLog.add(
    'API URL: $apiUrl',
  );

  try {
    await api.load();
  } catch (e, st) {
    DebugLog.error(
      'Startup storage error',
      e,
      st,
    );
  }

  runApp(
    const App(),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext c) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nexus AI',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: api.tok == null
          ? const Login()
          : const Home(),
    );
  }
}

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final e = TextEditingController();
  final p = TextEditingController();

  bool reg = false;
  bool busy = false;

  Future<void> go() async {
    setState(() {
      busy = true;
    });

    final ok = await api.auth(
      reg ? '/auth/register' : '/auth/login',
      e.text,
      p.text,
    );

    if (!mounted) return;

    setState(() {
      busy = false;
    });

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const Home(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication failed'),
        ),
      );
    }
  }

  @override
  void dispose() {
    e.dispose();
    p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 420,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nexus AI',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: e,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: p,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : go,
                      child: Text(
                        busy
                            ? 'Please wait'
                            : reg
                                ? 'Create account'
                                : 'Sign in',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        reg = !reg;
                      });
                    },
                    child: Text(
                      reg
                          ? 'Already have an account? Sign in'
                          : 'Create a new account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int page = 0;
  int cid = 0;

  List chats = [];
  List msgs = [];

  final input = TextEditingController();

  bool loading = false;

  final labels = [
    'Chats',
    'Projects',
    'Files',
    'Agents',
    'Research',
    'Images',
    'Settings',
  ];

  final icons = [
    Icons.chat,
    Icons.folder,
    Icons.description,
    Icons.smart_toy,
    Icons.search,
    Icons.image,
    Icons.settings,
  ];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      DebugLog.add(
        'Refreshing chats...',
      );

      chats = await api.get('/chats');

      if (chats.isEmpty) {
        final x = await api.post(
          '/chats',
          {
            'title': 'New Chat',
          },
        );

        cid = x['id'];
      } else {
        cid = chats.first['id'];
      }

      await openChat();

      if (mounted) {
        setState(() {});
      }
    } catch (e, st) {
      DebugLog.error(
        'Chat refresh failed',
        e,
        st,
      );

      if (mounted) {
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backend error: $e'),
          ),
        );
      }
    }
  }

  Future<void> openChat() async {
    if (cid == 0) return;

    final x = await api.get(
      '/chats/$cid',
    );

    msgs = x['messages'];

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> send() async {
    final t = input.text.trim();

    if (t.isEmpty) return;

    input.clear();

    setState(() {
      loading = true;
    });

    try {
      final x = await api.post(
        '/chats/$cid/messages',
        {
          'message': t,
          'model': 'auto',
        },
      );

      msgs.add({
        'role': 'user',
        'content': t,
      });

      msgs.add({
        'role': 'assistant',
        'content': x['reply'],
      });
    } catch (e) {
      msgs.add({
        'role': 'assistant',
        'content': 'Error: $e',
      });
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Widget chat() {
    return Column(
      children: [
        Expanded(
          child: msgs.isEmpty
              ? const Center(
                  child: Text(
                    'What can I help you with today?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: msgs.length,
                  itemBuilder: (c, i) {
                    final m = msgs[i];

                    return Align(
                      alignment: m['role'] == 'user'
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(
                          bottom: 12,
                        ),
                        padding: const EdgeInsets.all(14),
                        constraints: const BoxConstraints(
                          maxWidth: 700,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: m['role'] == 'user'
                              ? Theme.of(c)
                                  .colorScheme
                                  .primaryContainer
                              : Theme.of(c)
                                  .colorScheme
                                  .surfaceContainerHighest,
                        ),
                        child: Text(
                          m['content'],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                onPressed: api.upload,
                icon: const Icon(
                  Icons.attach_file,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: input,
                  onSubmitted: (_) => send(),
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Ask anything...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                onPressed: loading ? null : send,
                icon: const Icon(
                  Icons.send,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget placeholder(String x) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            x,
            style: const TextStyle(
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Module ready for the next integration step.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nexus AI · ${labels[page]}',
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DebugConsolePage(),
                ),
              );
            },
            icon: const Icon(
              Icons.bug_report_outlined,
            ),
          ),
          IconButton(
            onPressed: () async {
              final sp =
                  await SharedPreferences.getInstance();

              await sp.remove('token');

              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const Login(),
                  ),
                );
              }
            },
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: page,
            onDestinationSelected: (i) {
              setState(() {
                page = i;
              });
            },
            labelType:
                NavigationRailLabelType.all,
            destinations: List.generate(
              labels.length,
              (i) => NavigationRailDestination(
                icon: Icon(icons[i]),
                label: Text(labels[i]),
              ),
            ),
          ),
          Expanded(
            child: page == 0
                ? chat()
                : placeholder(labels[page]),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }
}

