import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas.dart';
import 'emprestimo_form.dart';
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

            // 🔹 Botão Novo Empréstimo
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmprestimoForm(
                      idCliente: cliente['id_cliente'],
                      idUsuario: Supabase.instance.client.auth.currentUser!.id,
                      onSaved: () {
                        // recarrega ao voltar
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FinanceiroPage(cliente: cliente),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text("Novo Empréstimo"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
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
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🔹 Linha 1: número e data
                                Text(
                                  "Nº ${emp['numero']}  |  Data do empréstimo: ${emp['data_inicio'] ?? ''}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // 🔹 Linha 2: montante e parcelas
                                Text(
                                  "Capital: ${fmtMoeda(emp['valor'])} | Juros: ${fmtMoeda(emp['juros'])} | "
                                  "Montante: ${fmtMoeda((num.tryParse("${emp['valor']}") ?? 0) + (num.tryParse("${emp['juros']}") ?? 0))} | "
                                  "${emp['parcelas']} parcelas de ${fmtMoeda(emp['prestacao'])}",
                                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
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
