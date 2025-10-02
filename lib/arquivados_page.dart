import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas_page.dart';
import 'utils.dart';

class ArquivadosPage extends StatefulWidget {
  const ArquivadosPage({super.key});

  @override
  State<ArquivadosPage> createState() => _ArquivadosPageState();
}

class _ArquivadosPageState extends State<ArquivadosPage> {
  late Future<List<Map<String, dynamic>>> _emprestimosArquivadosFuture;

  @override
  void initState() {
    super.initState();
    _emprestimosArquivadosFuture = _buscarEmprestimosArquivados();
  }

  Future<List<Map<String, dynamic>>> _buscarEmprestimosArquivados() async {
    final response = await Supabase.instance.client
        .from('emprestimos')
        .select('*, clientes(nome)')
        .eq('ativo', 'nao')
        .order('data_inicio', ascending: false);

    return (response as List).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> _reativarEmprestimo(String emprestimoId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reativar Empréstimo"),
        content: const Text("Deseja reativar este empréstimo?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reativar"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await Supabase.instance.client
          .from('emprestimos')
          .update({'ativo': 'sim'})
          .eq('id', emprestimoId);

      if (!mounted) return;
      
      setState(() {
        _emprestimosArquivadosFuture = _buscarEmprestimosArquivados();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Empréstimo reativado!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAF9F6),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Empréstimos Arquivados",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _emprestimosArquivadosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Erro: ${snapshot.error}"),
                  );
                }

                final emprestimos = snapshot.data ?? [];
                if (emprestimos.isEmpty) {
                  return const Center(
                    child: Text(
                      "Nenhum empréstimo arquivado.",
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: emprestimos.length,
                  itemBuilder: (context, index) {
                    final emp = emprestimos[index];
                    final cliente = emp['clientes'] is Map 
                        ? emp['clientes']['nome'] ?? 'Sem nome'
                        : 'Sem nome';

                    return Card(
                      color: Colors.grey[100],
                      child: ListTile(
                        leading: const Icon(Icons.archive, color: Colors.orange),
                        title: Text(cliente),
                        subtitle: Text(
                          "Valor: ${fmtMoeda(emp['valor'])} | "
                          "Parcelas: ${emp['parcelas']}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, color: Colors.blue),
                              onPressed: () {
                                emp['cliente'] = cliente;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ParcelasPage(emprestimo: emp),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.restore, color: Colors.green),
                              onPressed: () => _reativarEmprestimo(emp['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}