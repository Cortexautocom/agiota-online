import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas_service.dart';
//import 'utils.dart';

class ParcelasInativasPage extends StatefulWidget {
  final Map<String, dynamic> emprestimo;

  const ParcelasInativasPage({super.key, required this.emprestimo});

  @override
  State<ParcelasInativasPage> createState() => _ParcelasInativasPageState();
}

class _ParcelasInativasPageState extends State<ParcelasInativasPage> {
  late Future<List<Map<String, dynamic>>> _parcelasFuture;
  final ParcelasService service = ParcelasService();

  @override
  void initState() {
    super.initState();
    print("📂 ParcelasInativasPage aberto para emprestimo: ${widget.emprestimo}");
    final emprestimoId =
        widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'];
    print("🔎 Chamando buscarParcelas com id=$emprestimoId");
    _parcelasFuture = service.buscarParcelas(emprestimoId);
  }

  Future<void> _reativarEmprestimo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reativar Empréstimo"),
        content: const Text(
          "Tem certeza que deseja reativar este empréstimo?\n\n"
          "Ele voltará a aparecer na lista de empréstimos ativos.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Reativar"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await Supabase.instance.client
            .from('emprestimos')
            .update({'ativo': 'sim'})
            .eq('id', widget.emprestimo['id']);

        if (!mounted) return;

        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            content: const Text(
              "Empréstimo reativado com sucesso!",
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(
              "Erro ao reativar: $e",
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cliente = widget.emprestimo["cliente"] ?? "";
    final numero = widget.emprestimo["numero"] ?? "";
    final dataInicio = widget.emprestimo["data_inicio"] ?? "";

    final valor = service.parseMoeda("${widget.emprestimo["valor"] ?? "0"}");
    final juros = service.parseMoeda("${widget.emprestimo["juros"] ?? "0"}");
    

    return Scaffold(
      appBar: AppBar(
        title: Text("Parcelas (Arquivado) - $cliente"),
        backgroundColor: Colors.orange,
      ),
      body: Container(
        color: const Color(0xFFFAF9F6),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Nº $numero  |  Data do empréstimo: $dataInicio\n"
              "Capital: ${service.fmtMoeda(valor)} | "
              "Juros: ${service.fmtMoeda(juros)} | "
              "Montante: ${service.fmtMoeda(valor + juros)} | "
              "Prestação: ${service.fmtMoeda(widget.emprestimo['prestacao']?.toString().replaceAll('.', ','))}",
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              "📋 Visualização apenas - Empréstimo arquivado",
              style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _parcelasFuture,
                builder: (context, snapshot) {
                  print("📊 FutureBuilder snapshot: "
                      "state=${snapshot.connectionState} "
                      "hasError=${snapshot.hasError} "
                      "hasData=${snapshot.hasData}");
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    print("❌ Erro FutureBuilder: ${snapshot.error}");
                    return Center(
                      child: Text(
                        "Erro: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final parcelas = snapshot.data ?? [];
                  print("📦 Parcelas recebidas: ${parcelas.length}");
                  if (parcelas.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nenhuma parcela encontrada.",
                        style: TextStyle(color: Colors.black87),
                      ),
                    );
                  }

                  return _buildTabelaParcelas(parcelas);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _reativarEmprestimo,
        icon: const Icon(Icons.restore),
        label: const Text("Reativar Empréstimo"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildTabelaParcelas(List<Map<String, dynamic>> parcelas) {
    print("📝 Montando tabela de parcelas (${parcelas.length} itens)");
    double totalValor = 0;
    double totalJuros = 0;
    double totalDesconto = 0;
    double totalPgPrincipal = 0;
    double totalPgJuros = 0;

    for (final p in parcelas) {
      print("➡️ Parcela: $p");
      totalValor += service.parseMoeda(service.fmtMoeda(p['valor']));
      totalJuros += service.parseMoeda(service.fmtMoeda(p['juros']));
      totalDesconto += service.parseMoeda(service.fmtMoeda(p['desconto']));
      totalPgPrincipal += service.parseMoeda(service.fmtMoeda(p['pg_principal']));
      totalPgJuros += service.parseMoeda(service.fmtMoeda(p['pg_juros']));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columnSpacing: 12,
          headingRowColor: MaterialStateProperty.all(Colors.grey[400]),
          headingTextStyle: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
          dataTextStyle:
              const TextStyle(color: Colors.black87, fontSize: 13),
          columns: const [
            DataColumn(label: Text("Nº")),
            DataColumn(label: Text("Vencimento")),
            DataColumn(label: Text("     Valor")),
            DataColumn(label: Text("    Juros")),
            DataColumn(label: Text("Desconto")),
            DataColumn(label: Text("Pg. Principal")),
            DataColumn(label: Text("Pg. Juros")),
            DataColumn(label: Text("Valor Pago")),
            DataColumn(label: Text("    Saldo")),
            DataColumn(label: Text("  Data Pag.")),
          ],
          rows: [
            ...List.generate(parcelas.length, (i) {
              final p = parcelas[i];

              final residualAtual =
                  service.parseMoeda(service.fmtMoeda(p['valor'])) +
                      service.parseMoeda(service.fmtMoeda(p['juros'])) -
                      service.parseMoeda(service.fmtMoeda(p['desconto'])) -
                      (service.parseMoeda(service.fmtMoeda(p['pg_principal'])) +
                          service.parseMoeda(service.fmtMoeda(p['pg_juros'])));

              final bool parcelaPaga = residualAtual == 0;

              final rowColor =
                  parcelaPaga ? Colors.green.withOpacity(0.2) : Colors.grey[100];
              final textColor =
                  parcelaPaga ? Colors.green[800] : Colors.black87;

              return DataRow(
                color: MaterialStateProperty.all(rowColor),
                cells: [
                  DataCell(Text("${p['numero'] ?? ''}",
                      style: TextStyle(fontSize: 13, color: textColor))),
                  DataCell(Text(p['vencimento']?.toString() ?? '',
                      style: TextStyle(fontSize: 13, color: textColor))),
                  DataCell(Text(service.fmtMoeda(p['valor']),
                      style: TextStyle(fontSize: 13, color: textColor))),
                  DataCell(Text(service.fmtMoeda(p['juros']),
                      style: TextStyle(fontSize: 13, color: textColor))),
                  DataCell(Text(service.fmtMoeda(p['desconto']),
                      style: TextStyle(fontSize: 13, color: textColor))),
                  DataCell(Text(service.fmtMoeda(p['pg_principal']),
                      style: TextStyle(fontSize: 13, color: textColor))),
                  DataCell(Text(service.fmtMoeda(p['pg_juros']),
                      style: TextStyle(fontSize: 13, color: textColor))),
                  DataCell(Text(
                    service.fmtMoeda(
                      service.parseMoeda(service.fmtMoeda(p['pg_principal'])) +
                          service.parseMoeda(service.fmtMoeda(p['pg_juros'])),
                    ),
                    style: TextStyle(fontSize: 13, color: textColor),
                  )),
                  DataCell(Text(
                    residualAtual == 0
                        ? "R\$ 0,00"
                        : service.fmtMoeda(residualAtual),
                    style: TextStyle(fontSize: 13, color: textColor),
                  )),
                  DataCell(Text(p['data_pagamento']?.toString() ?? '',
                      style: TextStyle(fontSize: 13, color: textColor))),
                ],
              );
            }),
            DataRow(cells: [
              const DataCell(Text("")),
              const DataCell(Text("TOTAL",
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
              DataCell(Text(service.fmtMoeda(totalValor),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold))),
              DataCell(Text(service.fmtMoeda(totalJuros),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold))),
              DataCell(Text(service.fmtMoeda(totalDesconto),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold))),
              DataCell(Text(service.fmtMoeda(totalPgPrincipal),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold))),
              DataCell(Text(service.fmtMoeda(totalPgJuros),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold))),
              const DataCell(Text("")),
              const DataCell(Text("")),
              const DataCell(Text("")),
            ]),
          ],
        ),
      ),
    );
  }
}
