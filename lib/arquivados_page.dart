import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas_inativas_page.dart';
import 'utils.dart';
import 'package:intl/intl.dart';

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
    final response = await Supabase.instance.client
        .from('emprestimos')
        .select(
            'id, numero, valor, data_inicio, parcelas, observacao, juros, prestacao, id_usuario, ativo, clientes(nome)')
        .eq('ativo', 'nao')
        .eq('id_cliente', widget.cliente['id_cliente'])
        .order('data_inicio', ascending: false);

    return (response as List).map((e) => e as Map<String, dynamic>).toList();
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
                  return Center(child: Text("Erro: ${snapshot.error}"));
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
                                width: 70,
                                child: Center(child: Text("Nº")))),
                        DataColumn(
                            label: SizedBox(
                                width: 90,
                                child: Center(child: Text("Data Início")))),
                        DataColumn(
                            label: SizedBox(
                                width: 80,
                                child: Center(child: Text("Capital")))),
                        DataColumn(
                            label: SizedBox(
                                width: 80,
                                child: Center(child: Text("Juros")))),
                        DataColumn(
                            label: SizedBox(
                                width: 80,
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

                        final numero = emp['numero'] ?? '';
                        final dataInicio = _formatarData(emp['data_inicio']);

                        // 🔹 conversões seguras para double (igual ao FinanceiroPage)
                        final double capital = _asDouble(emp['valor']);
                        final double juros = _asDouble(emp['juros']);
                        final double total = capital + juros;
                        final double prestacao = _asDouble(emp['prestacao']);
                        final parcelas = emp['parcelas'] ?? '';

                        return DataRow(
                          onSelectChanged: (_) {
                            emp['cliente'] = cliente;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ParcelasInativasPage(emprestimo: emp),
                              ),
                            ).then((_) {
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
                                        style:
                                            const TextStyle(fontSize: 13))))),
                            DataCell(SizedBox(
                                width: 70,
                                child: Center(
                                    child: Text("$numero",
                                        style:
                                            const TextStyle(fontSize: 13))))),
                            DataCell(SizedBox(
                                width: 90,
                                child: Center(
                                    child: Text(dataInicio,
                                        style:
                                            const TextStyle(fontSize: 13))))),
                            DataCell(SizedBox(
                                width: 80,
                                child: Center(
                                    child: Text(fmtMoeda2(capital),
                                        style:
                                            const TextStyle(fontSize: 13))))),
                            DataCell(SizedBox(
                                width: 80,
                                child: Center(
                                    child: Text(fmtMoeda2(juros),
                                        style:
                                            const TextStyle(fontSize: 13))))),
                            DataCell(SizedBox(
                                width: 80,
                                child: Center(
                                    child: Text(fmtMoeda2(total),
                                        style:
                                            const TextStyle(fontSize: 13))))),
                            DataCell(SizedBox(
                                width: 120,
                                child: Center(
                                    child: Text(
                                        "$parcelas x ${fmtMoeda2(prestacao)}",
                                        style:
                                            const TextStyle(fontSize: 13))))),
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

  // 🔹 Mesmo padrão da FinanceiroPage
  double _asDouble(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0.0;
  }

  String _formatarData(String? dataISO) {
    if (dataISO == null || dataISO.isEmpty) return "-";
    try {
      final data = DateTime.parse(dataISO);
      return DateFormat("dd/MM/yyyy").format(data);
    } catch (_) {
      return dataISO;
    }
  }
}
