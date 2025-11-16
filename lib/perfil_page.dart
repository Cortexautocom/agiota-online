import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'alterar_senha.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();

  // Máscara de telefone (012) 9 9999-9999
  final telefoneFormatter = MaskTextInputFormatter(
    mask: '(###) # ####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('usuarios')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        _nomeController.text = response['nome'] ?? '';
        _emailController.text = response['email'] ?? user.email ?? '';
        _telefoneController.text = response['telefone'] ?? '';
      } else {
        // Preenche o e-mail do Auth se ainda não tiver registro
        _emailController.text = user.email ?? '';
      }
    } catch (e) {
      debugPrint("Erro ao carregar dados do usuário: $e");
    }
  }

  Future<void> _salvarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Verifica se já existe registro na tabela
      final existing = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      final dados = {
        'id': user.id,
        'nome': _nomeController.text.trim(),
        'email': _emailController.text.trim(),
        'telefone': _telefoneController.text.trim(),
      };

      if (existing == null) {
        // 🔹 Se não existe, cria um novo registro
        await Supabase.instance.client.from('usuarios').insert(dados);
      } else {
        // 🔹 Se existe, apenas atualiza
        await Supabase.instance.client
            .from('usuarios')
            .update(dados)
            .eq('id', user.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Perfil atualizado com sucesso!')),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Erro ao salvar perfil: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erro ao salvar perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validarEmail(String? value) {
    if (value == null || value.isEmpty) return 'Obrigatório';
    final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,4}$');
    if (!regex.hasMatch(value)) return 'E-mail inválido';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Perfil do Usuário")),
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
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: "Nome *",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? "Obrigatório" : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "E-mail *",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: _validarEmail,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _telefoneController,
                    decoration: const InputDecoration(
                      labelText: "Telefone",
                      border: OutlineInputBorder(),
                    ),
                    inputFormatters: [telefoneFormatter],
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _salvarPerfil,
                    icon: const Icon(Icons.save),
                    label: Text(_isLoading ? "Salvando..." : "Salvar"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2331),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(150, 48),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // BOTÃO ALTERAR SENHA ADICIONADO AQUI
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AlterarSenhaPage()),
                      );
                    },
                    icon: const Icon(Icons.lock),
                    label: const Text("Alterar Senha"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(150, 48),
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