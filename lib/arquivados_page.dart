import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas_inativas_page.dart';
import 'utils.dart';

class ArquivadosPage extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const ArquivadosPage({super.key, required this.cliente});

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
    print("🔎 Buscando empréstimos arquivados para cliente=${widget.cliente}");

    final response = await Supabase.instance.client
        .from('emprestimos')
        .select(
            'id, numero, valor, data_inicio, parcelas, observacao, juros, prestacao, id_usuario, ativo, clientes(nome)')
        .eq('ativo', 'nao')
        .eq('id_cliente', widget.cliente['id_cliente'])
        .order('data_inicio', ascending: false);

    print("📥 Resposta Supabase arquivados: $response");

    final lista = (response as List).map((e) => e as Map<String, dynamic>).toList();
    print("✅ Total de empréstimos arquivados encontrados: ${lista.length}");
    for (var e in lista) {
      print("➡️ Empréstimo ID=${e['id']} NUM=${e['numero']} VALOR=${e['valor']}");
    }

    return lista;
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

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor:
                          MaterialStateProperty.all(Colors.grey[300]),
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
                                child: Center(child: Text("Cliente")))),
                        DataColumn(
                            label: SizedBox(
                                width: 100,
                                child: Center(child: Text("Nº Empr.")))),
                        DataColumn(
                            label: SizedBox(
                                width: 100,
                                child: Center(child: Text("Data Início")))),
                        DataColumn(
                            label: SizedBox(
                                width: 110,
                                child: Center(child: Text("Capital")))),
                        DataColumn(
                            label: SizedBox(
                                width: 110,
                                child: Center(child: Text("Juros")))),
                        DataColumn(
                            label: SizedBox(
                                width: 110,
                                child: Center(child: Text("Total")))),
                        DataColumn(
                            label: SizedBox(
                                width: 120,
                                child: Center(child: Text("Parcelas")))),
                      ],
                      rows: emprestimos.map((emp) {
                        final cliente = emp['clientes'] is Map
                            ? emp['clientes']['nome'] ?? 'Sem nome'
                            : 'Sem nome';

                        print("📝 Montando linha da tabela para emprestimo ID=${emp['id']}");

                        return DataRow(
                          onSelectChanged: (_) {
                            print("👆 Clicou no empréstimo arquivado -> $emp");

                            emp['cliente'] = cliente;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ParcelasInativasPage(emprestimo: emp),
                              ),
                            ).then((_) {
                              print("🔄 Voltou de ParcelasInativasPage, recarregando lista");
                              setState(() {
                                _emprestimosArquivadosFuture =
                                    _buscarEmprestimosArquivados();
                              });
                            });
                          },
                          cells: [
                            DataCell(SizedBox(
                                width: 160,
                                child: Center(
                                    child: Text(cliente,
                                        style: const TextStyle(
                                            fontSize: 13))))),
                            DataCell(SizedBox(
                                width: 100,
                                child: Center(
                                    child: Text("${emp['numero'] ?? ''}",
                                        style: const TextStyle(
                                            fontSize: 13))))),
                            DataCell(SizedBox(
                                width: 100,
                                child: Center(
                                    child: Text(emp['data_inicio'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 13))))),
                            DataCell(SizedBox(
                                width: 110,
                                child: Center(
                                    child: Text(fmtMoeda(emp['valor']),
                                        style: const TextStyle(
                                            fontSize: 13))))),
                            DataCell(SizedBox(
                                width: 110,
                                child: Center(
                                    child: Text(fmtMoeda(emp['juros']),
                                        style: const TextStyle(
                                            fontSize: 13))))),
                            DataCell(SizedBox(
                                width: 110,
                                child: Center(
                                    child: Text(
                                        fmtMoeda(
                                            (num.tryParse("${emp['valor']}") ??
                                                    0) +
                                                (num.tryParse(
                                                        "${emp['juros']}") ??
                                                    0)),
                                        style: const TextStyle(
                                            fontSize: 13))))),
                            DataCell(SizedBox(
                                width: 120,
                                child: Center(
                                    child: Text(
                                        "${emp['parcelas']} x ${fmtMoeda(emp['prestacao'])}",
                                        style: const TextStyle(
                                            fontSize: 13))))),
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
    );
  }
}
