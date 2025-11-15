import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter/foundation.dart';
import 'clientes_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'relatorios_page.dart';
import 'login_page.dart';
import 'perfil_page.dart';
import 'funcoes_extras_page.dart';
import 'reset_password_page.dart';
import 'visao_geral.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔐 Configuração direta do Supabase com ANON KEY
  const supabaseUrl = 'https://mngwbikqaxlmbjzyvxii.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1uZ3diaWtxYXhsbWJqenl2eGlpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk3NzcyNDMsImV4cCI6MjA3NTM1MzI0M30.DPd8pcBZ-f20XhCsrsmG3Yls5KLn4wBCGFKYAcZlQRI';

  // 🔗 Inicializa o Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final client = Supabase.instance.client;

  // ✅ Detecta link de redefinição de senha (Supabase Magic Link)
  final uri = Uri.base;
  if (uri.queryParameters.containsKey('code')) {
    final code = uri.queryParameters['code']!;
    try {
      await client.auth.exchangeCodeForSession(code);
      debugPrint('✅ Link de recuperação verificado com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao verificar link de recuperação: $e');
    }
  }

  await initializeDateFormatting("pt_BR", null);

  final auth = Supabase.instance.client.auth;
  final session = auth.currentSession;

  // 🔹 Página inicial (login ou home)
  Widget startPage = const LoginPage();
  if (session != null) {
    startPage = const HomePage();
  }

  // ✅ Listener para detectar evento de redefinição de senha
  auth.onAuthStateChange.listen((data) {
    final AuthChangeEvent event = data.event;
    if (event == AuthChangeEvent.passwordRecovery) {
      debugPrint("🟢 Evento detectado: passwordRecovery → abrindo ResetPasswordPage");
      runApp(const MyApp(initialPage: ResetPasswordPage()));
    }
  });

  runApp(MyApp(initialPage: startPage));
}

class MyApp extends StatelessWidget {
  final Widget initialPage;
  const MyApp({super.key, required this.initialPage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale("pt", "BR"),
      supportedLocales: const [Locale("pt", "BR")],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFAF9F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1c2331),
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: initialPage,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String userDisplayName = "Usuário";

  @override
  void initState() {
    super.initState();
    _carregarNomeUsuario();
  }

  Future<void> _carregarNomeUsuario() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('usuarios')
          .select('nome')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null &&
          response['nome'] != null &&
          response['nome'].toString().isNotEmpty) {
        final nomeCompleto = response['nome'] as String;
        final primeiroNome = nomeCompleto.split(' ').first;
        setState(() {
          userDisplayName = primeiroNome;
        });
      } else {
        userDisplayName = user.email?.split('@').first ?? "Usuário";
      }
    } catch (e) {
      debugPrint("Erro ao carregar nome do usuário: $e");
      userDisplayName = user.email?.split('@').first ?? "Usuário";
    }

    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 🔹 Topbar fixa
          Container(
            height: 60,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 109, 160, 255),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  offset: Offset(0, 3),
                  blurRadius: 6,
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 🔹 Logo
                Row(
                  children: [
                    Image.asset(
                      'assets/logo_agiomestre.png',
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
                // 🔹 Menu do usuário
                PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (value) {
                    if (value == 'perfil') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PerfilPage()),
                      ).then((_) => _carregarNomeUsuario());
                    } else if (value == 'logout') {
                      _logout();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'perfil',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, color: Colors.black87),
                          SizedBox(width: 8),
                          Text('Perfil'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Sair'),
                        ],
                      ),
                    ),
                  ],
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: Color(0xFF1C2331)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        userDisplayName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 🔹 Conteúdo principal
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  backgroundColor: Colors.grey[200],
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination( // 🔹 NOVO ITEM
                      icon: Icon(Icons.dashboard),
                      label: Text('Visão geral'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people),
                      label: Text('Clientes'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bar_chart),
                      label: Text('Relatórios'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings),
                      label: Text('Funções extras'),
                    ),
                  ],
                ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: _buildPage(_selectedIndex),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const VisaoGeralPage(); // 🔹 NOVA PÁGINA
      case 1:
        return const ClientesPage();
      case 2:
        return const RelatoriosPage();
      case 3:
        return const FuncoesExtrasPage();
      default:
        return const Center(child: Text("Página não encontrada"));
    }
  }
}

Future<Map<String, dynamic>?> open_client_form(BuildContext context) async {
  final nomeController = TextEditingController();
  final cpfController = TextEditingController();
  final telefoneController = TextEditingController();
  final enderecoController = TextEditingController();
  final cidadeController = TextEditingController();
  final indicacaoController = TextEditingController();

  final cpfFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) # ####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Novo Cliente"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: "Nome"),
              ),
              TextField(
                controller: cpfController,
                decoration: const InputDecoration(labelText: "CPF"),
                keyboardType: TextInputType.number,
                inputFormatters: [cpfFormatter],
              ),
              TextField(
                controller: telefoneController,
                decoration: const InputDecoration(labelText: "Telefone"),
                keyboardType: TextInputType.phone,
                inputFormatters: [telefoneFormatter],
              ),
              TextField(
                controller: enderecoController,
                decoration: const InputDecoration(labelText: "Endereço"),
              ),
              TextField(
                controller: cidadeController,
                decoration: const InputDecoration(labelText: "Cidade"),
              ),
              TextField(
                controller: indicacaoController,
                decoration: const InputDecoration(labelText: "Indicação"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              final novoCliente = {
                "nome": nomeController.text,
                "cpf": cpfController.text,
                "telefone": telefoneController.text,
                "endereco": enderecoController.text,
                "cidade": cidadeController.text,
                "indicacao": indicacaoController.text,
                "id_usuario": Supabase.instance.client.auth.currentUser!.id,
              };
              Navigator.pop(context, novoCliente);
            },
            child: const Text("Salvar"),
          ),
        ],
      );
    },
  );
}