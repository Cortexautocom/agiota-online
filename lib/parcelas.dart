import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils.dart'; // 🔹 função fmtMoeda

class ParcelasPage extends StatefulWidget {
  final Map<String, dynamic> emprestimo;

  const ParcelasPage({super.key, required this.emprestimo});

  @override
  State<ParcelasPage> createState() => _ParcelasPageState();
}

class _ParcelasPageState extends State<ParcelasPage> {
  late Future<List<Map<String, dynamic>>> _parcelasFuture;

  final _formatter = NumberFormat.currency(locale: "pt_BR", symbol: "R\$");

  @override
  void initState() {
    super.initState();
    _parcelasFuture = _buscarParcelas();
  }

  Future<List<Map<String, dynamic>>> _buscarParcelas() async {
    final idEmprestimo =
        widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'];
    if (idEmprestimo == null) {
      throw Exception("ID do empréstimo não informado.");
    }

    final response = await Supabase.instance.client
        .from('parcelas')
        .select()
        .eq('id_emprestimo', idEmprestimo)
        .order('numero', ascending: true);

    return (response as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  String fmtMoeda(dynamic valor) {
    if (valor == null) return "";
    final txt = valor.toString();
    if (txt.trim().isEmpty) return "";
    if (txt.startsWith("R\$")) return txt; // já está formatado
    final numero = num.tryParse(txt.replaceAll(",", "."));
    if (numero == null) return txt;
    return _formatter.format(numero);
  }

  @override
  Widget build(BuildContext context) {
    final capital = num.tryParse("${widget.emprestimo["capital"]}") ?? 0;
    final juros = num.tryParse("${widget.emprestimo["juros"]}") ?? 0;
    final meses = widget.emprestimo["meses"]?.toString() ?? "0";
    final cliente = widget.emprestimo["cliente"] ?? "";

    return Scaffold(
      appBar: AppBar(
        title: Text("Parcelas - $cliente"),
      ),
      body: Container(
        color: const Color(0xFFFAF9F6), // 🔹 creme em vez de azul escuro
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Resumo do empréstimo
            Text(
              "Montante: ${fmtMoeda(capital + juros)} "
              "(Capital: ${fmtMoeda(capital)} + Juros: ${fmtMoeda(juros)}) | "
              "Parcelas: $meses",
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 12),

            // 🔹 Lista de parcelas
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _parcelasFuture,
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
                  final parcelas = snapshot.data ?? [];
                  if (parcelas.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nenhuma parcela encontrada.",
                        style: TextStyle(color: Colors.black87),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          MaterialStateProperty.all(Colors.grey[300]),
                      headingTextStyle: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      dataTextStyle: const TextStyle(color: Colors.black87),
                      columns: const [
                        DataColumn(label: Text("Nº")),
                        DataColumn(label: Text("Vencimento")),
                        DataColumn(label: Text("Valor")),
                        DataColumn(label: Text("Juros")),
                        DataColumn(label: Text("Desconto")),
                        DataColumn(label: Text("Pg. Principal")),
                        DataColumn(label: Text("Pg. Juros")),
                        DataColumn(label: Text("Valor Pago")),
                        DataColumn(label: Text("Saldo")),
                        DataColumn(label: Text("Data Pag.")),
                      ],
                      rows: parcelas.map((p) {
                        return DataRow(cells: [
                          DataCell(Text("${p['numero'] ?? ''}")),
                          DataCell(Text("${p['vencimento'] ?? ''}")),
                          DataCell(Text(fmtMoeda(p['valor']))),
                          DataCell(Text(fmtMoeda(p['juros']))),
                          DataCell(Text(fmtMoeda(p['desconto']))),
                          DataCell(Text(fmtMoeda(p['pg_principal']))),
                          DataCell(Text(fmtMoeda(p['pg_juros']))),
                          DataCell(Text(fmtMoeda(p['valor_pago']))),
                          DataCell(Text(fmtMoeda(p['saldo']))),
                          DataCell(Text("${p['data_pag'] ?? ''}")),
                        ]);
                      }).toList(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // 🔹 Botões
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: salvar parcelas
                  },
                  icon: const Icon(Icons.save),
                  label: const Text("Salvar Parcelas"),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: gerar PDF
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Gerar PDF"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: arquivar empréstimo
                  },
                  icon: const Icon(Icons.archive),
                  label: const Text("Arquivar"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
