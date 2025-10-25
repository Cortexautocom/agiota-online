import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  bool solicitacaoEnviada = false;
  bool redefinirSenha = false;
  bool carregando = false;

  @override
  void initState() {
    super.initState();

    // ✅ Detecta o fluxo "password recovery" quando o link do e-mail é aberto
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          redefinirSenha = true;
        });
      }
    });

    // Se já houver sessão válida, já permite redefinir
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      redefinirSenha = true;
    }
  }

  Future<void> _enviarEmailReset() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o e-mail cadastrado.')),
      );
      return;
    }

    setState(() => carregando = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://agiota-online.web.app/reset', // ✅ seu domínio público
      );

      setState(() => solicitacaoEnviada = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar e-mail: $e')),
      );
    } finally {
      setState(() => carregando = false);
    }
  }

  Future<void> _redefinirSenha() async {
    final senha = senhaController.text.trim();
    if (senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite a nova senha.')),
      );
      return;
    }

    setState(() => carregando = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: senha),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha redefinida com sucesso!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao redefinir senha: $e')),
      );
    } finally {
      setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1C2331), Color(0xFF3A506B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 400,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
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
                  Icon(
                    redefinirSenha ? Icons.lock_reset : Icons.email_outlined,
                    color: const Color(0xFF28A745),
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    redefinirSenha ? 'Redefinir Senha' : 'Recuperar Acesso',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C2331),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    redefinirSenha
                        ? 'Digite sua nova senha abaixo.'
                        : 'Informe seu e-mail para receber o link de redefinição.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // 🔹 Etapa 1 — Solicitar link
                  if (!redefinirSenha) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: "E-mail",
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 300,
                      child: ElevatedButton(
                        onPressed: carregando ? null : _enviarEmailReset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28A745),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: carregando
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Enviar link',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    if (solicitacaoEnviada)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text(
                          'Verifique seu e-mail e siga as instruções para redefinir sua senha.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                  ],

                  // 🔹 Etapa 2 — Redefinir senha
                  if (redefinirSenha) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: TextField(
                        controller: senhaController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Nova senha",
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 300,
                      child: ElevatedButton(
                        onPressed: carregando ? null : _redefinirSenha,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28A745),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: carregando
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Redefinir senha',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "← Voltar ao login",
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                      ),
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
