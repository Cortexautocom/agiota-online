import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas_service.dart';
import 'package:intl/intl.dart';

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
    final emprestimoId =
        widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'];
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final cliente = widget.emprestimo["cliente"] ?? "";
    final numero = widget.emprestimo["numero"] ?? "";
    final dataInicio = _formatarData(widget.emprestimo["data_inicio"]);

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
            // 🔹 Cabeçalho resumido
            Text(
              "Nº $numero  |  Data do empréstimo: $dataInicio\n"
              "Capital: ${service.fmtMoeda(widget.emprestimo['valor'])} | "
              "Juros: ${service.fmtMoeda(widget.emprestimo['juros'])} | "
              "Montante: ${service.fmtMoeda(_asDouble(widget.emprestimo['valor']) + _asDouble(widget.emprestimo['juros']))} | "
              "Prestação: ${service.fmtMoeda(widget.emprestimo['prestacao'])}",
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              "📋 Visualização apenas - Empréstimo arquivado",
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columnSpacing: 12,
          headingRowColor: MaterialStateProperty.all(Colors.grey[400]),
          headingTextStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          dataTextStyle: const TextStyle(color: Colors.black87, fontSize: 13),
          columns: const [
            DataColumn(label: Text("Nº")),
            DataColumn(label: Text("Vencimento")),
            DataColumn(label: Text("Valor")),
            DataColumn(label: Text("Juros")),
            DataColumn(label: Text("Desconto")),
            DataColumn(label: Text("Pg. Principal")),
            DataColumn(label: Text("Pg. Juros")),
            DataColumn(label: Text("Valor Pago")),
            DataColumn(label: Text("Residual")),
            DataColumn(label: Text("Data Pag.")),
          ],
          rows: parcelas.map((p) {
            final residual = _asDouble(p['residual']);
            final bool parcelaPaga = residual == 0;
            final rowColor = parcelaPaga
                ? Colors.green.withOpacity(0.2)
                : Colors.grey[100];
            final textColor =
                parcelaPaga ? Colors.green[800] : Colors.black87;

            return DataRow(
              color: MaterialStateProperty.all(rowColor),
              cells: [
                DataCell(Text("${p['numero'] ?? ''}",
                    style: TextStyle(fontSize: 13, color: textColor))),
                DataCell(Text(_formatarData(p['vencimento']),
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
                DataCell(Text(service.fmtMoeda(p['valor_pago']),
                    style: TextStyle(fontSize: 13, color: textColor))),
                DataCell(Text(service.fmtMoeda(residual),
                    style: TextStyle(fontSize: 13, color: textColor))),
                DataCell(Text(_formatarData(p['data_pagamento']),
                    style: TextStyle(fontSize: 13, color: textColor))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // 🔹 Funções auxiliares idênticas à FinanceiroPage
  double _asDouble(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0.0;
  }

  String _formatarData(dynamic data) {
    if (data == null || data.toString().isEmpty) return "-";
    try {
      final dt = DateTime.parse(data.toString());
      return DateFormat("dd/MM/yyyy").format(dt);
    } catch (_) {
      return data.toString();
    }
  }
}
