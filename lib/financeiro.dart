import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas.dart';
import 'utils.dart'; // 🔹 função fmtMoeda

class FinanceiroPage extends StatelessWidget {
  final Map<String, dynamic> cliente;

  const FinanceiroPage({super.key, required this.cliente});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Financeiro - ${cliente['nome']}"),
      ),
      body: Container(
        color: const Color(0xFFFAF9F6), // 🔹 fundo creme
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Empréstimos do Cliente",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // 🔹 Lista de empréstimos do cliente
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: Supabase.instance.client
                    .from('emprestimos')
                    .select()
                    .eq('id_cliente', cliente['id_cliente'])
                    .eq('ativo', 'sim')
                    .order('data_inicio'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Erro: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final emprestimos = (snapshot.data as List?)
                          ?.map((e) => e as Map<String, dynamic>)
                          .toList() ??
                      [];

                  if (emprestimos.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nenhum empréstimo encontrado.",
                        style: TextStyle(color: Colors.black87),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: emprestimos.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: Colors.black26),
                    itemBuilder: (context, index) {
                      final emp = emprestimos[index];
                      return Card(
                        color: Colors.white,
                        child: ListTile(
                          title: Text(
                            "Empréstimo de ${fmtMoeda(emp['capital'])}",
                            style: const TextStyle(color: Colors.black87),
                          ),
                          subtitle: Text(
                            "Meses: ${emp['meses'] ?? 0} | Juros: ${fmtMoeda(emp['juros'])}",
                            style: const TextStyle(color: Colors.black54),
                          ),
                          onTap: () {
                            emp['cliente'] = cliente['nome'];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ParcelasPage(emprestimo: emp),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // 🔹 Botões extras
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Garantias ainda não implementado")),
                );
              },
              icon: const Icon(Icons.account_balance),
              label: const Text("Garantias"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Arquivados ainda não implementado")),
                );
              },
              icon: const Icon(Icons.archive),
              label: const Text("Arquivados"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
