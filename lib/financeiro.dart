import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas_page.dart';
import 'emprestimo_form.dart';
import 'utils.dart'; // 🔹 função fmtMoeda

class FinanceiroPage extends StatelessWidget {
  final Map<String, dynamic> cliente;

  const FinanceiroPage({super.key, required this.cliente});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // 🔹 Empréstimos Ativos, Garantias, Arquivados
      child: Scaffold(
        appBar: AppBar(
          title: Text("Financeiro - ${cliente['nome']}"),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: Colors.grey[200], // 🔹 cor de fundo da barra
              child: TabBar(
                labelColor: Colors.white, // cor do texto da aba ativa
                unselectedLabelColor: Colors.black54, // cor do texto das inativas
                indicator: BoxDecoration(
                  color: Colors.blue, // 🔹 cor da aba ativa
                  borderRadius: BorderRadius.circular(12), // 🔹 cantos arredondados
                ),
                indicatorSize: TabBarIndicatorSize.tab, // ocupa toda a aba
                tabs: const [
                  Tab(child: SizedBox(height: 32, child: Center(child: Text("Empréstimos Ativos")))),
                  Tab(child: SizedBox(height: 32, child: Center(child: Text("Garantias")))),
                  Tab(child: SizedBox(height: 32, child: Center(child: Text("Arquivados")))),
                ],
              ),
            ),
          ),
        ),

        body: TabBarView(
          children: [
            // 🔹 Aba 1: Empréstimos Ativos
            Container(
              color: const Color(0xFFFAF9F6), // fundo creme
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
                            idUsuario:
                                Supabase.instance.client.auth.currentUser!.id,
                            onSaved: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FinanceiroPage(cliente: cliente),
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 🔹 Lista de empréstimos
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: Supabase.instance.client
                          .from('emprestimos')
                          .select()
                          .eq('id_cliente', cliente['id_cliente'])
                          .eq('ativo', 'sim')
                          .order('data_inicio'),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
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

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal, // 🔹 rolagem horizontal
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical, // 🔹 rolagem vertical
                            child: DataTable(
                              showCheckboxColumn: false, // 🔹 remove o quadrado
                              headingRowColor: MaterialStateProperty.all(Colors.grey[300]),
                              headingTextStyle: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                              dataTextStyle: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                              columns: const [
                                DataColumn(
                                  label: SizedBox(
                                    width: 160,
                                    child: Center(child: Text("Cliente")),
                                  ),
                                ),
                                DataColumn(
                                  label: SizedBox(
                                    width: 100,
                                    child: Center(child: Text("Nº Empr.")),
                                  ),
                                ),
                                DataColumn(
                                  label: SizedBox(
                                    width: 100,
                                    child: Center(child: Text("Data Início")),
                                  ),
                                ),
                                DataColumn(
                                  label: SizedBox(
                                    width: 110,
                                    child: Center(child: Text("Capital")),
                                  ),
                                ),
                                DataColumn(
                                  label: SizedBox(
                                    width: 110,
                                    child: Center(child: Text("Juros")),
                                  ),
                                ),
                                DataColumn(
                                  label: SizedBox(
                                    width: 110,
                                    child: Center(child: Text("Montante")),
                                  ),
                                ),
                                DataColumn(
                                  label: SizedBox(
                                    width: 120,
                                    child: Center(child: Text("Prestação")),
                                  ),
                                ),
                              ],
                              rows: emprestimos.map((emp) {
                                return DataRow(
                                  onSelectChanged: (_) { // 🔹 restaurado
                                    emp['cliente'] = cliente['nome'];
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ParcelasPage(emprestimo: emp),
                                      ),
                                    );
                                  },
                                  cells: [
                                    DataCell(
                                      SizedBox(
                                        width: 160,
                                        child: Center(
                                          child: Text(cliente['nome'], style: const TextStyle(fontSize: 13)),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 100,
                                        child: Center(
                                          child: Text("${emp['numero'] ?? ''}", style: const TextStyle(fontSize: 13)),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 100,
                                        child: Center(
                                          child: Text(emp['data_inicio'] ?? '', style: const TextStyle(fontSize: 13)),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 110,
                                        child: Center(
                                          child: Text(fmtMoeda(emp['valor']), style: const TextStyle(fontSize: 13)),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 110,
                                        child: Center(
                                          child: Text(fmtMoeda(emp['juros']), style: const TextStyle(fontSize: 13)),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 110,
                                        child: Center(
                                          child: Text(
                                            fmtMoeda((num.tryParse("${emp['valor']}") ?? 0) +
                                                (num.tryParse("${emp['juros']}") ?? 0)),
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 120,
                                        child: Center(
                                          child: Text(
                                            "${emp['parcelas']} x ${fmtMoeda(emp['prestacao'])}",
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 Aba 2: Garantias (placeholder)
            const Center(
              child: Text(
                "Garantias ainda não implementadas",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),

            // 🔹 Aba 3: Arquivados (placeholder)
            const Center(
              child: Text(
                "Arquivados ainda não implementados",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
