import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlterarSenhaPage extends StatefulWidget {
  const AlterarSenhaPage({super.key});

  @override
  State<AlterarSenhaPage> createState() => _AlterarSenhaPageState();
}

class _AlterarSenhaPageState extends State<AlterarSenhaPage> {
  final _formKey = GlobalKey<FormState>();
  final _senhaAtualController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _isLoading = false;
  bool _obscureSenhaAtual = true;
  bool _obscureNovaSenha = true;
  bool _obscureConfirmarSenha = true;

  Future<void> _alterarSenha() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      // 🔹 CORREÇÃO: Chamada correta da edge function
      final response = await supabase.functions.invoke(
        'alterar-senha',
        body: {
          'nova_senha': _novaSenhaController.text.trim(),
        },
      );

      // Verifica se a resposta foi bem-sucedida
      if (response.status >= 200 && response.status < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Senha alterada com sucesso!')),
        );
        Navigator.pop(context);
      } else {
        final errorData = response.data;
        final errorMessage = errorData is Map && errorData['error'] != null 
            ? errorData['error'].toString() 
            : 'Erro ao alterar senha';
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint("Erro ao alterar senha: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erro ao alterar senha: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validarSenha(String? value) {
    if (value == null || value.isEmpty) return 'Obrigatório';
    if (value.length < 6) return 'A senha deve ter pelo menos 6 caracteres';
    return null;
  }

  String? _validarConfirmacaoSenha(String? value) {
    if (value == null || value.isEmpty) return 'Obrigatório';
    if (value != _novaSenhaController.text) return 'As senhas não coincidem';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Alterar Senha")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Campo Senha Atual
                  TextFormField(
                    controller: _senhaAtualController,
                    decoration: InputDecoration(
                      labelText: "Senha Atual *",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureSenhaAtual 
                            ? Icons.visibility_off 
                            : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureSenhaAtual = !_obscureSenhaAtual;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureSenhaAtual,
                    validator: (value) =>
                        value == null || value.isEmpty ? "Obrigatório" : null,
                  ),
                  const SizedBox(height: 20),
                  
                  // Campo Nova Senha
                  TextFormField(
                    controller: _novaSenhaController,
                    decoration: InputDecoration(
                      labelText: "Nova Senha *",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNovaSenha 
                            ? Icons.visibility_off 
                            : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNovaSenha = !_obscureNovaSenha;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureNovaSenha,
                    validator: _validarSenha,
                  ),
                  const SizedBox(height: 20),
                  
                  // Campo Confirmar Nova Senha
                  TextFormField(
                    controller: _confirmarSenhaController,
                    decoration: InputDecoration(
                      labelText: "Repita a Nova Senha *",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmarSenha 
                            ? Icons.visibility_off 
                            : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmarSenha = !_obscureConfirmarSenha;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureConfirmarSenha,
                    validator: _validarConfirmacaoSenha,
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Botão Alterar Senha
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _alterarSenha,
                    icon: const Icon(Icons.lock_reset),
                    label: Text(_isLoading ? "Alterando..." : "Alterar Senha"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2331),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(150, 48),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text("Cancelar"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _senhaAtualController.dispose();
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }
}