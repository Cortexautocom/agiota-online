import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ADICIONE ESTA LINHA
import 'clientes_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'relatorios_page.dart';
import 'config/env.dart'; // ADICIONE ESTA LINHA

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Carrega as variáveis do .env para desenvolvimento
  await dotenv.load(fileName: '.env');

  // 🔹 Agora usando as credenciais do arquivo de configuração
  await Supabase.initialize(
    url: Env.supabaseUrl,          // ← ALTERADO
    anonKey: Env.supabaseAnonKey,  // ← ALTERADO
  );

  await initializeDateFormatting("pt_BR", null);

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale("pt", "BR"), // 👈 força pt-BR
      supportedLocales: const [
        Locale("pt", "BR"),
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFAF9F6), // 🔹 fundo creme em todas as páginas
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
      home: const LoginPage(),
    );
  }
}


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  bool carregando = false;
  String erro = "";

  Future<void> _login() async {
    setState(() {
      carregando = true;
      erro = "";
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: senhaController.text.trim(),
      );

      if (response.user != null) {
        final user = response.user!;

        // 🔹 Garante que o usuário também exista na tabela public.usuarios
        await Supabase.instance.client.from('usuarios').upsert({
          'id': user.id,        // mesmo UUID do auth.users
          'email': user.email,  // ajuste conforme colunas da sua tabela usuarios
        });

        // Login OK → vai para HomePage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        setState(() {
          erro = "Usuário ou senha inválidos.";
        });
      }
    } catch (e) {
      setState(() {
        erro = "Erro: $e";
      });
    } finally {
      setState(() {
        carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Login",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "E-mail"),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: senhaController,
                decoration: const InputDecoration(labelText: "Senha"),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              if (erro.isNotEmpty)
                Text(
                  erro,
                  style: const TextStyle(color: Colors.red),
                ),
              ElevatedButton(
                onPressed: carregando ? null : _login,
                child: carregando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Entrar"),
              ),
            ],
          ),
        ),
      ),
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
              color: Color(0xFF1C2331), // fundo escuro elegante
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  offset: Offset(0, 3),
                  blurRadius: 6,
                )
              ],
            ),
            child: Row(
              children: const [
                Icon(Icons.attach_money, color: Colors.greenAccent, size: 28),
                SizedBox(width: 10),
                Text(
                  "Agiota Online",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 🔹 Conteúdo: menu lateral + páginas
          Expanded(
            child: Row(
              children: [
                // Menu lateral
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
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard),
                      label: Text('Painel'),
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

                // Conteúdo central
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
        return const Center(
          child: Text("📊 Painel inicial"),
        );
      case 1:
        return const ClientesPage();
      case 2:
        return const RelatoriosPage();
      case 3:
        return const Center(
          child: Text("⚙️ Funções extras"),
        );
      default:
        return const Center(
          child: Text("Página não encontrada"),
        );
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

  // 🔹 Máscaras
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


