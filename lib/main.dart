import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'financeiro.dart'; // 🔹 importa a nova tela
import 'home.dart'; // 🔹 vamos mover HomePage para arquivo separado
import 'clientes_page.dart'; // 🔹 vamos mover ClientesPage para arquivo separado


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Substitua pelos dados do seu projeto Supabase
  await Supabase.initialize(
    url: 'https://zqvbgfqzdcejgxthdmht.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxdmJnZnF6ZGNlamd4dGhkbWh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUxMTI5ODAsImV4cCI6MjA3MDY4ODk4MH0.e4NhuarlGNnXrXUWKdLmGoa1DGejn2jmgpbRR_Ztyqw',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
        return const Center(
          child: Text("📑 Relatórios"),
        );
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

// 🔹 Página de Clientes
class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  late Future<List<Map<String, dynamic>>> _clientesFuture;

  @override
  void initState() {
    super.initState();
    _clientesFuture = _buscarClientes();
  }

  Future<List<Map<String, dynamic>>> _buscarClientes() async {
    final response = await Supabase.instance.client.from('clientes').select();
    return (response as List).map((e) => e as Map<String, dynamic>).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _clientesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro ao carregar: ${snapshot.error}"));
          }
          final clientes = snapshot.data ?? [];
          if (clientes.isEmpty) {
            return const Center(child: Text("Nenhum cliente encontrado."));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: clientes.length,
            separatorBuilder: (context, index) => const Divider(height: 8),
            itemBuilder: (context, index) {
              final cliente = clientes[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.person, size: 22),
                title: Text(cliente['nome'] ?? 'Sem nome'),
                subtitle: Text(
                  "CPF: ${cliente['cpf'] ?? '-'} | Cidade: ${cliente['cidade'] ?? '-'}",
                ),
                onTap: () {
                  // 🔹 Navega para o financeiro do cliente
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FinanceiroPage(cliente: cliente),
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await Supabase.instance.client
                        .from('clientes')
                        .delete()
                        .eq('id_cliente', cliente['id_cliente']);
                    setState(() {
                      _clientesFuture = _buscarClientes(); // recarrega lista
                    });
                  },
                ),
              );
            },
          );
        },
      ),

      // 🔹 Botão flutuante para adicionar cliente
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final novoCliente = await open_client_form(context);
          if (novoCliente != null) {
            await Supabase.instance.client.from('clientes').insert(novoCliente);
            setState(() {
              _clientesFuture = _buscarClientes(); // recarrega lista
            });
          }
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
