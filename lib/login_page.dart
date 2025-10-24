import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'reset_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔹 Fundo com gradiente
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color.fromARGB(255, 93, 134, 223), Color.fromARGB(255, 214, 214, 214)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 🔹 Conteúdo principal (formulário de login)
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: 500,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Image.asset(
                      'assets/logo_agiomestre.png',
                      width: 300,
                    ),
                    const SizedBox(height: 24),

                    // Campo de e-mail
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        labelText: "E-mail",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo de senha
                    TextField(
                      controller: senhaController,
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        labelText: "Senha",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Link Esqueci minha senha
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ResetPasswordPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "Esqueci minha senha",
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Botão de login
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: _fazerLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28A745),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Entrar",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🔹 Rodapé fixo com imagem e textos
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo_empresa.png', // ajuste conforme o nome do arquivo
                  width: 150,
                  height: 96,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Cortex-IA — Automação Inteligente",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 119, 119, 119),
                    shadows: [
                      Shadow(
                        color: Color.fromARGB(108, 255, 255, 255),
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  "Todos os direitos reservados",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color.fromARGB(255, 119, 119, 119),
                    shadows: [
                      Shadow(
                        color: Color.fromARGB(108, 255, 255, 255),
                        offset: Offset(0, 1),
                        blurRadius: 1,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fazerLogin() async {
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha e-mail e senha!')),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: senha,
      );

      if (res.user != null) {
        final usuario = res.user!;
        await verificarAcordosVencidosAoLogin(usuario.id);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha no login. Verifique seus dados.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  Future<void> verificarAcordosVencidosAoLogin(String idUsuario) async {
    try {
      final supabase = Supabase.instance.client;
      final hojeISO = DateTime.now().toIso8601String().split('T').first;

      final parcelasComAcordo = await supabase
          .from('parcelas')
          .select('id, comentario, juros_acordo')
          .eq('id_usuario', idUsuario)
          .lte('vencimento', hojeISO)
          .not('data_prevista', 'is', null);

      for (final parcela in parcelasComAcordo) {
        final comentarioAtual = (parcela['comentario'] ?? '').toString();
        final jurosAcordo = (parcela['juros_acordo'] ?? 0).toDouble();

        String novoComentario = comentarioAtual;
        if (jurosAcordo > 0 &&
            !comentarioAtual.contains('Acordo vencido de R\$')) {
          final valorFmt = jurosAcordo.toStringAsFixed(2).replaceAll('.', ',');
          novoComentario = comentarioAtual.isEmpty
              ? 'Acordo vencido de R\$ $valorFmt'
              : '$comentarioAtual | Acordo vencido de R\$ $valorFmt';
        }

        await supabase.from('parcelas').update({
          'data_prevista': null,
          'juros_acordo': null,
          'comentario': novoComentario,
        }).eq('id', parcela['id']);
      }

      debugPrint("⚠️ Acordos vencidos removidos e comentários atualizados.");
    } catch (e) {
      debugPrint("Erro ao verificar acordos vencidos: $e");
    }
  }
}
