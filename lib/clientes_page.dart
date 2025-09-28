import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'financeiro.dart';

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
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _clientesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text("Erro ao carregar: ${snapshot.error}",
                      style: const TextStyle(color: Colors.white)));
            }
            final clientes = snapshot.data ?? [];
            if (clientes.isEmpty) {
              return const Center(
                  child: Text("Nenhum cliente encontrado.",
                      style: TextStyle(color: Colors.white)));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: clientes.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 8, color: Colors.white24),
              itemBuilder: (context, index) {
                final cliente = clientes[index];
                return ListTile(
                  dense: true,
                  leading:
                      const Icon(Icons.person, size: 22, color: Colors.white),
                  title: Text(cliente['nome'] ?? 'Sem nome',
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    "CPF: ${cliente['cpf'] ?? '-'} | Cidade: ${cliente['cidade'] ?? '-'}",
                    style: const TextStyle(color: Colors.white70),
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
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await Supabase.instance.client
                          .from('clientes')
                          .delete()
                          .eq('id_cliente', cliente['id_cliente']);
                      setState(() {
                        _clientesFuture = _buscarClientes();
                      });
                    },
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () async {
              final novoCliente = await open_client_form(context);
              if (novoCliente != null) {
                await Supabase.instance.client.from('clientes').insert(novoCliente);
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
  // usa a mesma função que você já tem no main.dart
  return null;
}
