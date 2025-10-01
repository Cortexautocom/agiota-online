import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'financeiro.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'editar_cliente_page.dart';

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
    return Stack(
      children: [
        Container(
          color: const Color(0xFFFAF9F6), // 🔹 fundo creme
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _clientesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Erro ao carregar: ${snapshot.error}",
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              final clientes = snapshot.data ?? [];
              if (clientes.isEmpty) {
                return const Center(
                  child: Text(
                    "Nenhum cliente encontrado.",
                    style: TextStyle(color: Colors.black87),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: clientes.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 8, color: Colors.black26),
                itemBuilder: (context, index) {
                  final cliente = clientes[index];
                  return Card(
                    color: Colors.white,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.person,
                        size: 22,
                        color: Colors.black87,
                      ),
                      title: Text(
                        cliente['nome'] ?? 'Sem nome',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      subtitle: Text(
                        "CPF: ${cliente['cpf'] ?? '-'} | Cidade: ${cliente['cidade'] ?? '-'}",
                        style: const TextStyle(color: Colors.black54),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FinanceiroPage(cliente: cliente),
                          ),
                        );
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: "Editar cliente",
                        onPressed: () async {
                          final resultado = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditarClientePage(cliente: cliente),
                            ),
                          );

                          if (resultado == true) {
                            setState(() {
                              _clientesFuture = _buscarClientes(); // recarrega lista após editar/excluir
                            });
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // 🔹 Botão flutuante
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () async {
              final novoCliente = await open_client_form(context);
              if (novoCliente != null) {
                await Supabase.instance.client
                    .from('clientes')
                    .insert(novoCliente);
                setState(() {
                  _clientesFuture = _buscarClientes();
                });
              }
            },
            backgroundColor: Colors.green,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// 🔹 mantém a função de criar novo cliente
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
