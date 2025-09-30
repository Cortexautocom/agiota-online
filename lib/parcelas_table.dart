import 'package:flutter/material.dart';
import 'parcelas_service.dart';
import 'acordo_dialog.dart';

class ParcelasTable extends StatefulWidget {
  final Map<String, dynamic> emprestimo;
  final List<Map<String, dynamic>> parcelas;

  const ParcelasTable({
    super.key,
    required this.emprestimo,
    required this.parcelas,
  });

  @override
  State<ParcelasTable> createState() => ParcelasTableState();
}

class ParcelasTableState extends State<ParcelasTable> {
  final ParcelasService service = ParcelasService();
  final List<Map<String, TextEditingController>> _controllers = [];

  @override
  void initState() {
    super.initState();
    _preencherControllers();
  }

  void _preencherControllers() {
    _controllers.clear();
    for (final p in widget.parcelas) {
      _controllers.add({
        'vencimento':
            TextEditingController(text: p['vencimento']?.toString() ?? ''),
        'valor': TextEditingController(text: service.fmtMoeda(p['valor'])),
        'juros': TextEditingController(text: service.fmtMoeda(p['juros'])),
        'desconto':
            TextEditingController(text: service.fmtMoeda(p['desconto'])),
        'pg_principal':
            TextEditingController(text: service.fmtMoeda(p['pg_principal'])),
        'pg_juros':
            TextEditingController(text: service.fmtMoeda(p['pg_juros'])),
        'data_pagamento':
            TextEditingController(text: p['data_pagamento']?.toString() ?? ''),
      });
    }
  }

  /// 🔹 Coleta os valores editados e salva no Supabase
  Future<bool> salvarParcelas() async {
    try {
      final parcelasAtualizadas = <Map<String, dynamic>>[];

      for (int i = 0; i < widget.parcelas.length; i++) {
        final p = widget.parcelas[i];
        final c = _controllers[i];

        parcelasAtualizadas.add({
          'id': p['id'],
          'id_emprestimo':
              widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'],
          'numero': p['numero'],
          'vencimento': c['vencimento']!.text,
          'valor': service.parseMoeda(c['valor']!.text),
          'juros': service.parseMoeda(c['juros']!.text),
          'desconto': service.parseMoeda(c['desconto']!.text),
          'pg_principal': service.parseMoeda(c['pg_principal']!.text),
          'pg_juros': service.parseMoeda(c['pg_juros']!.text),
          'valor_pago': (service.parseMoeda(c['pg_principal']!.text) +
              service.parseMoeda(c['pg_juros']!.text)),
          'residual': (service.parseMoeda(c['valor']!.text) +
              service.parseMoeda(c['juros']!.text) -
              service.parseMoeda(c['desconto']!.text) -
              (service.parseMoeda(c['pg_principal']!.text) +
                  service.parseMoeda(c['pg_juros']!.text))),
          'data_pagamento': c['data_pagamento']!.text,
          'id_usuario': widget.emprestimo['id_usuario'],
        });
      }

      await service.salvarParcelasNoSupabase(
        widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'],
        widget.emprestimo['id_usuario'],
        parcelasAtualizadas,
      );

      return true;
    } catch (e) {
      debugPrint("Erro ao salvar parcelas: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Totais
    double totalValor = 0;
    double totalJuros = 0;
    double totalDesconto = 0;
    double totalPgPrincipal = 0;
    double totalPgJuros = 0;

    for (var i = 0; i < widget.parcelas.length; i++) {
      totalValor += service.parseMoeda(_controllers[i]['valor']!.text);
      totalJuros += service.parseMoeda(_controllers[i]['juros']!.text);
      totalDesconto += service.parseMoeda(_controllers[i]['desconto']!.text);
      totalPgPrincipal +=
          service.parseMoeda(_controllers[i]['pg_principal']!.text);
      totalPgJuros += service.parseMoeda(_controllers[i]['pg_juros']!.text);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columnSpacing: 12,
          headingRowColor: MaterialStateProperty.all(Colors.grey[300]),
          headingTextStyle: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
          dataTextStyle: const TextStyle(color: Colors.black87, fontSize: 13),
          columns: const [
            DataColumn(label: Text("Nº")),
            DataColumn(label: Text("Vencimento")),
            DataColumn(label: Text("     Valor")),
            DataColumn(label: Text("    Juros")),
            DataColumn(label: Text("Desconto")),
            DataColumn(label: Text("  Calc.")),
            DataColumn(label: Text("Pg. Principal")),
            DataColumn(label: Text("Pg. Juros")),
            DataColumn(label: Text("Valor Pago")),
            DataColumn(label: Text("    Saldo")),
            DataColumn(label: Text("  Data Pag.")),
            DataColumn(label: Text("Ações")),
          ],
          rows: [
            ...List.generate(widget.parcelas.length, (i) {
              final p = widget.parcelas[i];
              final c = _controllers[i];

              return DataRow(cells: [
                DataCell(Text("${p['numero'] ?? ''}",
                    style: const TextStyle(fontSize: 13))),
                DataCell(TextField(
                  controller: c['vencimento'],
                  inputFormatters: [service.dateMaskFormatter()],
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                      border: InputBorder.none, hintText: "dd/mm/aaaa"),
                )),
                DataCell(Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      c['valor']!.text = service.fmtMoeda(
                          service.parseMoeda(c['valor']!.text));
                      setState(() {});
                    }
                  },
                  child: TextField(
                    controller: c['valor'],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                )),
                DataCell(Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      c['juros']!.text = service.fmtMoeda(
                          service.parseMoeda(c['juros']!.text));
                      setState(() {});
                    }
                  },
                  child: TextField(
                    controller: c['juros'],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                )),
                DataCell(Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      c['desconto']!.text = service.fmtMoeda(
                          service.parseMoeda(c['desconto']!.text));
                      setState(() {});
                    }
                  },
                  child: TextField(
                    controller: c['desconto'],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                )),
                DataCell(IconButton(
                  icon: const Icon(Icons.calculate,
                      size: 20, color: Colors.blue),
                  onPressed: () {
                    final capital =
                        num.tryParse("${widget.emprestimo["valor"]}") ?? 0;
                    final jurosSupabase =
                        num.tryParse("${widget.emprestimo["juros"]}") ?? 0;
                    final qtdParcelas =
                        num.tryParse("${widget.emprestimo["parcelas"]}") ?? 1;
                    final jurosDigitado =
                        service.parseMoeda(c['juros']!.text);
                    final desconto = service.parseMoeda(c['desconto']!.text);

                    final pgPrincipal = capital / qtdParcelas;
                    final pgJuros =
                        jurosSupabase / qtdParcelas + jurosDigitado - desconto;

                    c['pg_principal']!.text = service.fmtMoeda(pgPrincipal);
                    c['pg_juros']!.text = service.fmtMoeda(pgJuros);

                    setState(() {});
                  },
                )),
                DataCell(Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      c['pg_principal']!.text = service.fmtMoeda(
                          service.parseMoeda(c['pg_principal']!.text));
                      setState(() {});
                    }
                  },
                  child: TextField(
                    controller: c['pg_principal'],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                )),
                DataCell(Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      c['pg_juros']!.text = service.fmtMoeda(
                          service.parseMoeda(c['pg_juros']!.text));
                      setState(() {});
                    }
                  },
                  child: TextField(
                    controller: c['pg_juros'],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                )),
                DataCell(Text(
                  service.fmtMoeda(
                    service.parseMoeda(c['pg_principal']!.text) +
                        service.parseMoeda(c['pg_juros']!.text),
                  ),
                  style: const TextStyle(fontSize: 13),
                )),
                DataCell(Text(
                  service.fmtMoeda(
                    service.parseMoeda(c['valor']!.text) +
                        service.parseMoeda(c['juros']!.text) -
                        service.parseMoeda(c['desconto']!.text) -
                        (service.parseMoeda(c['pg_principal']!.text) +
                            service.parseMoeda(c['pg_juros']!.text)),
                  ),
                  style: const TextStyle(fontSize: 13),
                )),
                DataCell(TextField(
                  controller: c['data_pagamento'],
                  inputFormatters: [service.dateMaskFormatter()],
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                      border: InputBorder.none, hintText: "dd/mm/aaaa"),
                )),
                DataCell(IconButton(
                  icon: const Text("🤝", style: TextStyle(fontSize: 20)),
                  tooltip: "Fazer acordo",
                  onPressed: () => abrirAcordoDialog(context, p),
                )),
              ]);
            }),
            // 🔹 Linha TOTAL
            DataRow(cells: [
              const DataCell(Text("")),
              const DataCell(Text("TOTAL",
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
              DataCell(Text(service.fmtMoeda(totalValor),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold))),
              DataCell(Text(service.fmtMoeda(totalJuros),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold))),
              DataCell(Text(service.fmtMoeda(totalDesconto),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold))),
              const DataCell(Text("")),
              DataCell(Text(service.fmtMoeda(totalPgPrincipal),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold))),
              DataCell(Text(service.fmtMoeda(totalPgJuros),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold))),
              const DataCell(Text("")),
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
