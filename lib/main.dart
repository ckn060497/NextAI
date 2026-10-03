```dart
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://example.com/nexus-ai-api',
);

class ApiNotFoundPage extends StatelessWidget {
  final String? path;

  const ApiNotFoundPage({super.key, this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Not Found'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off,
                size: 72,
              ),
              const SizedBox(height: 20),
              const Text(
                '404',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Backend endpoint not found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                path == null
                    ? 'The API server is not deployed yet or this endpoint does not exist.'
                    : 'The requested API endpoint was not found:\n$path',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
              child: Text('No runtime logs yet. Try an API action.'),
            );
          }

          return SelectionArea(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: DebugLog.entries.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  DebugLog.entries[i],
                  style: const TextStyle(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(
    this.message, {
    this.statusCode,
  });

  @override
  String toString() => message;
}

class Api {
  String? tok;

  Future<void> load() async {
    tok = (await SharedPreferences.getInstance()).getString('token');

    DebugLog.add(
      'App storage loaded; token=${tok == null ? "absent" : "present"}',
    );
  }

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (tok != null) 'Authorization': 'Bearer $tok',
      };

  Uri uri(String path) {
    final u = Uri.parse(
      '${apiUrl.replaceFirst(RegExp(r'/+$'), '')}'
      '${path.startsWith('/') ? path : '/$path'}',
    );

    return u;
  }

  dynamic decode(http.Response response) {
    dynamic body;

    try {
      body = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      body = null;
    }

    DebugLog.add(
      'HTTP ${response.statusCode} <- '
      '${response.request?.method ?? "?"} '
      '${response.request?.url ?? ""}',
    );

    if (response.statusCode >= 400) {
      final detail = body is Map && body['detail'] != null
          ? body['detail'].toString()
          : 'API request failed (${response.statusCode})';

      DebugLog.error('API error: $detail');

      throw ApiException(
        detail,
        statusCode: response.statusCode,
      );
    }

    return body;
  }

  Future<dynamic> get(String path) async {
    final u = uri(path);

    DebugLog.add('GET -> $u');

    try {
      final r = await http
          .get(
            u,
            headers: headers,
          )
          .timeout(
            const Duration(seconds: 30),
          );

      return decode(r);
    } catch (e, st) {
      final err = _networkError(e);

      DebugLog.error(
        'GET failed: $u',
        err,
        st,
      );

      throw err;
    }
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final u = uri(path);

    DebugLog.add('POST -> $u');

    try {
      final r = await http
          .post(
            u,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 90),
          );

      return decode(r);
    } catch (e, st) {
      final err = _networkError(e);

      DebugLog.error(
        'POST failed: $u',
        err,
        st,
      );

      throw err;
    }
  }

  Future<bool> auth(
    String path,
    String email,
    String password,
  ) async {
    final u = uri(path);

    DebugLog.add('AUTH POST -> $u');

    try {
      final r = await http
          .post(
            u,
            headers: headers,
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
          );

      final body = decode(r);

      if (body is! Map || body['token'] == null) {
        DebugLog.error(
          'Authentication response did not contain a token.',
        );

        return false;
      }

      tok = body['token'].toString();

      final sp = await SharedPreferences.getInstance();

      await sp.setString(
        'token',
        tok!,
      );

      DebugLog.add(
        'Authentication succeeded.',
      );

      return true;
    } catch (e, st) {
      final err = _networkError(e);

      DebugLog.error(
        'Authentication failed',
        err,
        st,
      );

      return false;
    }
  }

  Future<void> upload() async {
    DebugLog.add(
      'Opening file picker...',
    );

    final f = await FilePicker.platform.pickFiles(
      withData: true,
    );

    if (f == null) {
      DebugLog.add(
        'File picker cancelled.',
      );

      return;
    }

    final x = f.files.single;

    if (x.bytes == null) {
      throw ApiException(
        'Could not read the selected file.',
      );
    }

    final u = uri('/files');

    DebugLog.add(
      'UPLOAD -> $u (${x.name})',
    );

    try {
      final req = http.MultipartRequest(
        'POST',
        u,
      );

      req.headers['Accept'] = 'application/json';

      if (tok != null) {
        req.headers['Authorization'] = 'Bearer $tok';
      }

      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          x.bytes!,
          filename: x.name,
        ),
      );

      final response = await req
          .send()
          .timeout(
            const Duration(seconds: 90),
          );

      final body = await response.stream.bytesToString();

      DebugLog.add(
        'UPLOAD response: ${response.statusCode}',
      );

      if (response.statusCode >= 400) {
        dynamic parsed;

        try {
          parsed = jsonDecode(body);
        } catch (_) {}

        throw ApiException(
          parsed is Map && parsed['detail'] != null
              ? parsed['detail'].toString()
              : 'Upload failed (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      DebugLog.add(
        'Upload succeeded.',
      );
    } catch (e, st) {
      final err = _networkError(e);

      DebugLog.error(
        'Upload failed',
        err,
        st,
      );

      throw err;
    }
  }

  Exception _networkError(Object error) {
    if (error is ApiException) {
      return error;
    }

    if (error is TimeoutException) {
      return ApiException(
        'The backend request timed out. '
        'Check the API server and API_URL.',
      );
    }

    if (error is http.ClientException) {
      return ApiException(
        'Cannot reach the Nexus AI backend at $apiUrl.',
      );
    }

    return ApiException(
      'Backend connection failed: $error',
    );
  }
}

final api = Api();

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
            'Module readyrue); final ok=await api.auth(reg?'/auth/register':'/auth/login',e.text,p.text); setState(()=>busy=false);
    if(ok&&mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const Home()));
    else if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Authentication failed')));
  }
  @override Widget build(BuildContext c)=>Scaffold(body:Center(child:SizedBox(width:420,child:Card(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.auto_awesome,size:56),const SizedBox(height:12),const Text('Nexus AI',style:TextStyle(fontSize:30,fontWeight:FontWeight.bold)),
    const SizedBox(height:24),TextField(controller:e,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder())),
    const SizedBox(height:12),TextField(controller:p,obscureText:true,decoration:const InputDecoration(labelText:'Password',border:OutlineInputBorder())),
    const SizedBox(height:20),SizedBox(width:double.infinity,child:FilledButton(onPressed:busy?null:go,child:Text(busy?'Please wait':reg?'Create account':'Sign in'))),
    TextButton(onPressed:()=>setState(()=>reg=!reg),child:Text(reg?'Already have an account? Sign in':'Create a new account'))
  ])))));
}

class Home extends StatefulWidget{const Home({super.key});State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{
  int page=0,cid=0; List chats=[]; List msgs=[]; final input=TextEditingController(); bool loading=false;
  final labels=['Chats','Projects','Files','Agents','Research','Images','Settings'];
  final icons=[Icons.chat,Icons.folder,Icons.description,Icons.smart_toy,Icons.search,Icons.image,Icons.settings];
  @override void initState(){super.initState();refresh();}
  Future<void> refresh() async {
    try {
      DebugLog.add('Refreshing chats...');
      chats = await api.get('/chats');
      if (chats.isEmpty) {
        final x = await api.post('/chats', {'title': 'New Chat'});
        cid = x['id'];
      } else {
        cid = chats.first['id'];
      }
      await openChat();
      if (mounted) setState(() {});
    } catch (e, st) {
      DebugLog.error('Chat refresh failed', e, st);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backend error: $e')),
        );
      }
    }
  }
  Future<void> openChat() async {if(cid==0)return;final x=await api.get('/chats/$cid');msgs=x['messages'];setState((){});}
  Future<void> send() async {final t=input.text.trim();if(t.isEmpty)return;input.clear();setState(()=>loading=true);
    try{final x=await api.post('/chats/$cid/messages',{'message':t,'model':'auto'});msgs.add({'role':'user','content':t});msgs.add({'role':'assistant','content':x['reply']});}catch(e){msgs.add({'role':'assistant','content':'Error: $e'});}setState(()=>loading=false);}
  Widget chat()=>Column(children:[
    Expanded(child:msgs.isEmpty?const Center(child:Text('What can I help you with today?',style:TextStyle(fontSize:24,fontWeight:FontWeight.w600))):
      ListView.builder(padding:const EdgeInsets.all(20),itemCount:msgs.length,itemBuilder:(c,i){final m=msgs[i];return Align(alignment:m['role']=='user'?Alignment.centerRight:Alignment.centerLeft,
        child:Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(14),constraints:const BoxConstraints(maxWidth:700),
          decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),color:m['role']=='user'?Theme.of(c).colorScheme.primaryContainer:Theme.of(c).colorScheme.surfaceContainerHighest),child:Text(m['content'])));}),),
    Padding(padding:const EdgeInsets.all(16),child:Row(children:[IconButton(onPressed:api.upload,icon:const Icon(Icons.attach_file)),Expanded(child:TextField(controller:input,onSubmitted:(_)=>send(),minLines:1,maxLines:5,decoration:const InputDecoration(hintText:'Ask anything...',border:OutlineInputBorder()))),IconButton(onPressed:loading?null:send,icon:const Icon(Icons.send))]))
  ]);
  Widget placeholder(String x)=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.auto_awesome,size:48),const SizedBox(height:12),Text(x,style:const TextStyle(fontSize:24)),const SizedBox(height:8),const Text('Module ready for the next integration step.')]));
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text('Nexus AI · ${labels[page]}'),actions:[IconButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const DebugConsolePage())),icon:const Icon(Icons.bug_report_outlined)),IconButton(onPressed:()async{final sp=await SharedPreferences.getInstance();await sp.remove('token');if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const Login()));},icon:const Icon(Icons.logout))]),
    body:Row(children:[NavigationRail(selectedIndex:page,onDestinationSelected:(i)=>setState(()=>page=i),labelType:NavigationRailLabelType.all,
      destinations:List.generate(labels.length,(i)=>NavigationRailDestination(icon:Icon(icons[i]),label:Text(labels[i])))),Expanded(child:page==0?chat():placeholder(labels[page]))]));
}
