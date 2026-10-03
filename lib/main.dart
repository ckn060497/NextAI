import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugLog {
  static final List<String> entries = <String>[];

  static void add(String message) {
    final line = '${DateTime.now().toIso8601String()}  $message';
    entries.add(line);
    if (entries.length > 300) {
      entries.removeAt(0);
    }
    debugPrint(line);
  }
}

class DebugConsolePage extends StatefulWidget {
  const DebugConsolePage({super.key});

  @override
  State<DebugConsolePage> createState() => _DebugConsolePageState();
}

class _DebugConsolePageState extends State<DebugConsolePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Console'),
        actions: [
          IconButton(
            tooltip: 'Clear logs',
            onPressed: () {
              DebugLog.entries.clear();
              setState(() {});
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: DebugLog.entries.isEmpty
          ? const Center(child: Text('No debug messages yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: DebugLog.entries.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectableText(
                    DebugLog.entries[index],
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                );
              },
            ),
    );
  }
}

class LocalStorage {
  static const String messagesKey = 'offline_messages';
  static const String filesKey = 'offline_files';

  static Future<List<Map<String, dynamic>>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(messagesKey);

    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      DebugLog.add('Could not load messages: $e');
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> saveMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(messagesKey, jsonEncode(messages));
  }

  static Future<List<String>> loadFiles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(filesKey) ?? <String>[];
  }

  static Future<void> saveFiles(List<String> files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(filesKey, files);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(messagesKey);
    await prefs.remove(filesKey);
  }
}

class LocalAI {
  static Future<String> generateReply(String prompt) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final text = prompt.trim();
    final lower = text.toLowerCase();

    if (lower.contains('hello') ||
        lower.contains('hi') ||
        lower.contains('hey')) {
      return 'Hello! I am running in offline mode. '
          'I can demonstrate the chat interface without a backend.';
    }

    if (lower.contains('who are you') || lower.contains('what are you')) {
      return 'I am Nexus AI running in local demo mode. '
          'No server or authentication is being used.';
    }

    if (lower.contains('help')) {
      return 'Try sending a message, attaching a local file, or opening '
          'Projects, Files, Agents, Research, Images, and Settings.';
    }

    if (lower.contains('offline')) {
      return 'Offline mode is active. Messages and selected file names are '
          'stored locally on this device.';
    }

    return 'Offline demo response: I received your message:\n\n"$text"\n\n'
        'A real AI response requires either your backend API or an '
        'on-device AI model.';
  }
}

class LocalFiles {
  static Future<String?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      return result.files.single.name;
    } catch (e) {
      DebugLog.add('File picker error: $e');
      return null;
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    DebugLog.add('Flutter error: ${details.exception}');
  };

  ui.PlatformDispatcher.instance.onError = (error, stack) {
    DebugLog.add('Unhandled error: $error');
    return true;
  };

  DebugLog.add('Nexus AI started in offline mode.');
  DebugLog.add('Authentication and backend API are disabled.');

  runApp(const App());
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
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      home: const Home(),
    );
  }
}

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nexus AI')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_open, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Offline mode',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Authentication is disabled in this build.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const Home(),
                        ),
                      );
                    },
                    child: const Text('Continue'),
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
  final TextEditingController input = TextEditingController();
  final ScrollController chatScroll = ScrollController();

  int page = 0;
  bool loading = false;

  List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];
  List<String> files = <String>[];

  final List<String> labels = <String>[
    'Chats',
    'Projects',
    'Files',
    'Agents',
    'Research',
    'Images',
    'Settings',
  ];

  final List<IconData> icons = <IconData>[
    Icons.chat_bubble_outline,
    Icons.folder_copy_outlined,
    Icons.insert_drive_file_outlined,
    Icons.smart_toy_outlined,
    Icons.search_outlined,
    Icons.image_outlined,
    Icons.settings_outlined,
  ];

  @override
  void initState() {
    super.initState();
    loadLocalData();
  }

  Future<void> loadLocalData() async {
    final loadedMessages = await LocalStorage.loadMessages();
    final loadedFiles = await LocalStorage.loadFiles();

    if (!mounted) {
      return;
    }

    setState(() {
      messages = loadedMessages;
      files = loadedFiles;
    });

    DebugLog.add(
      'Loaded ${messages.length} messages and ${files.length} files.',
    );
  }

  Future<void> send() async {
    final text = input.text.trim();

    if (text.isEmpty || loading) {
      return;
    }

    input.clear();

    setState(() {
      messages.add(<String, dynamic>{
        'role': 'user',
        'text': text,
        'time': DateTime.now().toIso8601String(),
      });
      loading = true;
    });

    await LocalStorage.saveMessages(messages);
    DebugLog.add('Local message saved.');

    try {
      final reply = await LocalAI.generateReply(text);

      if (!mounted) {
        return;
      }

      setState(() {
        messages.add(<String, dynamic>{
          'role': 'assistant',
          'text': reply,
          'time': DateTime.now().toIso8601String(),
        });
        loading = false;
      });

      await LocalStorage.saveMessages(messages);
      DebugLog.add('Offline response generated.');
      _scrollChatToBottom();
    } catch (e) {
      DebugLog.add('Local AI error: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
        messages.add(<String, dynamic>{
          'role': 'assistant',
          'text': 'Offline processing failed: $e',
          'time': DateTime.now().toIso8601String(),
        });
      });

      await LocalStorage.saveMessages(messages);
    }
  }

  Future<void> attachFile() async {
    final name = await LocalFiles.pickFile();

    if (name == null || name.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    if (!files.contains(name)) {
      files.add(name);
      await LocalStorage.saveFiles(files);

      setState(() {});

      DebugLog.add('Added local file: $name');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $name')),
      );
    }
  }

  Future<void> clearChat() async {
    setState(() {
      messages.clear();
    });

    await LocalStorage.saveMessages(messages);
    DebugLog.add('Chat history cleared.');
  }

  Future<void> clearLocalData() async {
    await LocalStorage.clearAll();

    if (!mounted) {
      return;
    }

    setState(() {
      messages.clear();
      files.clear();
    });

    DebugLog.add('All local data cleared.');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local data cleared.')),
    );
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!chatScroll.hasClients) {
        return;
      }

      chatScroll.animateTo(
        chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Widget chat() {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? _emptyChat()
              : ListView.builder(
                  controller: chatScroll,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final role = message['role']?.toString() ?? 'assistant';
                    final text = message['text']?.toString() ?? '';
                    final isUser = role == 'user';

                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 760),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: SelectableText(text),
                      ),
                    );
                  },
                ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(),
          ),
        _composer(),
      ],
    );
  }

  Widget _emptyChat() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            const Text(
              'Nexus AI',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Offline mode',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Authentication and backend requests are disabled.\n'
              'Your demo chat history is stored locally.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Attach file',
              onPressed: attachFile,
              icon: const Icon(Icons.attach_file),
            ),
            Expanded(
              child: TextField(
                controller: input,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => send(),
                decoration: InputDecoration(
                  hintText: 'Message Nexus AI...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: loading ? null : send,
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }

  Widget projects() {
    return _modulePage(
      icon: Icons.folder_copy_outlined,
      title: 'Projects',
      description: 'Create and organize projects locally.',
      child: FilledButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Project creation is available in offline demo mode.'),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
    );
  }

  Widget filesPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Files',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Selected file names are stored locally.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: attachFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Add File'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: files.isEmpty
                ? const Center(child: Text('No files added yet.'))
                : ListView.separated(
                    itemCount: files.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(files[index]),
                        trailing: IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            final removed = files.removeAt(index);
                            await LocalStorage.saveFiles(files);

                            if (mounted) {
                              setState(() {});
                            }

                            DebugLog.add('Removed local file: $removed');
                          },
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
      icon: Icons.smart_toy_outlined,
      title: 'Agents',
      description:
          'Local agent interface. Network-powered agents are disabled in this build.',
      child: FilledButton(
        onPressed: () {
          setState(() {
            page = 0;
          });
        },
        child: const Text('Open Chat'),
      ),
    );
  }

  Widget research() {
    return _modulePage(
      icon: Icons.search_outlined,
      title: 'Research',
      description:
          'Research requires internet access or a backend service. '
          'This offline build provides the interface only.',
      child: OutlinedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Research is disabled in offline mode.'),
            ),
          );
        },
        icon: const Icon(Icons.info_outline),
        label: const Text('Offline Mode'),
      ),
    );
  }

  Widget imagesPage() {
    return _modulePage(
      icon: Icons.image_outlined,
      title: 'Images',
      description:
          'Image generation requires an image model or backend service. '
          'This offline build keeps the page available.',
      child: OutlinedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image generation is disabled in offline mode.'),
            ),
          );
        },
        icon: const Icon(Icons.info_outline),
        label: const Text('Offline Mode'),
      ),
    );
  }

  Widget settings() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.cloud_off_outlined),
                title: Text('Backend'),
                subtitle: Text('Disabled'),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.lock_open_outlined),
                title: Text('Authentication'),
                subtitle: Text('Bypassed for offline mode'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Debug Console'),
                subtitle: const Text('View local application logs'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DebugConsolePage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.tonalIcon(
          onPressed: clearChat,
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('Clear Chat'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final shouldClear = await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  title: const Text('Clear all local data?'),
                  content: const Text(
                    'This removes locally stored chat history and file names.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext, false);
                      },
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(dialogContext, true);
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                );
              },
            );

            if (shouldClear == true) {
              await clearLocalData();
            }
          },
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('Clear All Local Data'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Nexus AI offline build\n'
          'No login or backend API is required to open the app.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _modulePage({
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _currentPage() {
    switch (page) {
      case 0:
        return chat();
      case 1:
        return projects();
      case 2:
        return filesPage();
      case 3:
        return agents();
      case 4:
        return research();
      case 5:
        return imagesPage();
      case 6:
        return settings();
      default:
        return chat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Text('Nexus AI · ${labels[page]}'),
        actions: [
          IconButton(
            tooltip: 'Debug Console',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DebugConsolePage(),
                ),
              );
            },
            icon: const Icon(Icons.bug_report_outlined),
          ),
          if (page == 0)
            IconButton(
              tooltip: 'Clear chat',
              onPressed: messages.isEmpty ? null : clearChat,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Row(
        children: [
          if (!compact)
            NavigationRail(
              selectedIndex: page,
              onDestinationSelected: (index) {
                setState(() {
                  page = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              destinations: List<NavigationRailDestination>.generate(
                labels.length,
                (index) => NavigationRailDestination(
                  icon: Icon(icons[index]),
                  selectedIcon: Icon(icons[index]),
                  label: Text(labels[index]),
                ),
              ),
            ),
          Expanded(
            child: _currentPage(),
          ),
        ],
      ),
      bottomNavigationBar: compact
          ? NavigationBar(
              selectedIndex: page,
              onDestinationSelected: (index) {
                setState(() {
                  page = index;
                });
              },
              destinations: List<NavigationDestination>.generate(
                labels.length,
                (index) => NavigationDestination(
                  icon: Icon(icons[index]),
                  selectedIcon: Icon(icons[index]),
                  label: labels[index],
                ),
              ),
            )
          : null,
    );
  }

  @override
  void dispose() {
    input.dispose();
    chatScroll.dispose();
    super.dispose();
  }
}
