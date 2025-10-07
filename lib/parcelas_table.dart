import 'package:flutter/material.dart';
import 'parcelas_service.dart';
import 'acordo_dialog.dart';
//import 'package:intl/intl.dart';
import 'utils.dart';

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
        'vencimento': TextEditingController(
          text: formatarData(p['vencimento']?.toString()),
        ),
        'valor': TextEditingController(text: service.fmtMoeda(p['valor'])),
        'juros': TextEditingController(text: service.fmtMoeda(p['juros'])),
        'desconto': TextEditingController(text: service.fmtMoeda(p['desconto'])),
        'pg_principal': TextEditingController(text: service.fmtMoeda(p['pg_principal'])),
        'pg_juros': TextEditingController(text: service.fmtMoeda(p['pg_juros'])),
        'data_pagamento': TextEditingController(
          text: formatarData(p['data_pagamento']?.toString()),
        ),
      });
    }
  }

  String? _toIsoDate(String text) {
    if (text.isEmpty) return null;
    final parts = text.split('/');
    if (parts.length != 3) return null;
    final dia = parts[0].padLeft(2, '0');
    final mes = parts[1].padLeft(2, '0');
    final ano = parts[2];
    return "$ano-$mes-$dia";
  }

  /// 🔹 Coleta os valores editados e salva no Supabase
  Future<bool> salvarParcelas() async {
    try {
      final parcelasAtualizadas = <Map<String, dynamic>>[];

      for (int i = 0; i < widget.parcelas.length; i++) {
        final p = widget.parcelas[i];
        final c = _controllers[i];

        final valor = service.parseMoeda(c['valor']!.text);
        final juros = service.parseMoeda(c['juros']!.text);
        final desconto = service.parseMoeda(c['desconto']!.text);
        final pgPrincipal = service.parseMoeda(c['pg_principal']!.text);
        final pgJuros = service.parseMoeda(c['pg_juros']!.text);
        final valorPago = pgPrincipal + pgJuros;
        final residual = valor + juros - desconto - valorPago;
        final dataPag = c['data_pagamento']!.text.trim();

        final valorTotalOriginal = valor + juros - desconto;

        if (residual == 0 && dataPag.isEmpty) {
          if (!mounted) return false;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              content: const Text(
                "Inclua a data do pagamento antes de sair da página.",
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
          return false;
        }

        if ((residual.abs() > 0.01) && (residual.abs() < (valorTotalOriginal - 0.01))) {
          if (!mounted) return false;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              content: const Text(
                "Não é possível salvar com parcelas pagas parcialmente.\n\n"
                "Faça os devidos ajustes antes de sair da página.",
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
          return false;
        }

        if (dataPag.isNotEmpty && valorPago == 0) {
          if (!mounted) return false;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              content: const Text(
                "Existem parcelas com data lançada, mas sem o pagamento inserido.",
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
          return false;
        }

        // 🔹 NOVA REGRA: Se há pagamento, mas sem data de pagamento, bloqueia
        if (valorPago > 0 && dataPag.isEmpty) {
          if (!mounted) return false;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              content: const Text(
                "Há parcelas com pagamento inserido, mas sem data de pagamento.\n\n"
                "Inclua a data antes de sair da página.",
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
          return false;
        }

        parcelasAtualizadas.add({
          'id': p['id'],
          'id_emprestimo':
              widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'],
          'numero': p['numero'],
          'vencimento': _toIsoDate(c['vencimento']!.text),
          'valor': valor,
          'juros': juros,
          'desconto': desconto,
          'pg_principal': pgPrincipal,
          'pg_juros': pgJuros,
          'valor_pago': valorPago,
          'residual': residual,
          'data_pagamento': _toIsoDate(c['data_pagamento']!.text.trim()),
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
      if (!mounted) return false;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(
            "Erro ao salvar parcelas: $e",
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
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalValor = 0;
    double totalJuros = 0;
    double totalDesconto = 0;
    double totalPgPrincipal = 0;
    double totalPgJuros = 0;

    for (var i = 0; i < widget.parcelas.length; i++) {
      totalValor += service.parseMoeda(_controllers[i]['valor']!.text);
      totalJuros += service.parseMoeda(_controllers[i]['juros']!.text);
      totalDesconto += service.parseMoeda(_controllers[i]['desconto']!.text);
      totalPgPrincipal += service.parseMoeda(_controllers[i]['pg_principal']!.text);
      totalPgJuros += service.parseMoeda(_controllers[i]['pg_juros']!.text);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: MaterialStateProperty.all(Colors.grey[300]),
          dataRowMinHeight: 38, // 🔹 Altura mínima das linhas
          dataRowMaxHeight: 42,          
          headingTextStyle: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
          dataTextStyle: const TextStyle(color: Colors.black87, fontSize: 13),
          columns: const [
            DataColumn(label: SizedBox(width: 50, child: Text("Nº"))),
            DataColumn(label: SizedBox(width: 100, child: Text("Vencimento"))),
            DataColumn(label: SizedBox(width: 90, child: Text("     Valor"))),
            DataColumn(label: SizedBox(width: 80, child: Text("Juros"))),
            DataColumn(label: SizedBox(width: 90, child: Text("Desconto"))),
            DataColumn(label: SizedBox(width: 60, child: Text(" Calc."))),
            DataColumn(label: SizedBox(width: 110, child: Text("Pg. Principal"))),
            DataColumn(label: SizedBox(width: 100, child: Text("Pg. Juros"))),
            DataColumn(label: SizedBox(width: 100, child: Text("Valor Pago"))),
            DataColumn(label: SizedBox(width: 100, child: Text("    Saldo"))),
            DataColumn(label: SizedBox(width: 110, child: Text("  Data Pag."))),
            DataColumn(label: SizedBox(width: 90, child: Text("Ações"))),
          ],
          rows: [
            ...List.generate(widget.parcelas.length, (i) {
              final p = widget.parcelas[i];
              final c = _controllers[i];

              final vencimentoTxt = p['vencimento']?.toString() ?? "";
              DateTime? vencimento;
              try {
                vencimento = DateTime.parse(vencimentoTxt); // lê direto yyyy-MM-dd
              } catch (_) {
                vencimento = null;
              }

              final hoje = DateTime.now();
              final temAcordo = p['data_prevista'] != null &&
                  p['data_prevista'].toString().isNotEmpty;

              // 🔹 calcula residual atual
              final residualAtual = service.parseMoeda(c['valor']!.text) +
                  service.parseMoeda(c['juros']!.text) -
                  service.parseMoeda(c['desconto']!.text) -
                  (service.parseMoeda(c['pg_principal']!.text) +
                      service.parseMoeda(c['pg_juros']!.text));

              final estaEmAtraso = vencimento != null &&
                  vencimento.isBefore(DateTime(hoje.year, hoje.month, hoje.day));

              // 🔹 NOVA REGRA: Se residual == 0 → formatação verde (prioridade máxima)
              final bool parcelaPaga = residualAtual.abs() < 0.01;

              // 🔹 Define cores com prioridade: Paga > Acordo > Atraso > Normal
              final rowColor = parcelaPaga
                  ? Colors.green.withOpacity(0.2)
                  : (temAcordo && residualAtual != 0)
                      ? Colors.orange.withOpacity(0.2)
                      : estaEmAtraso
                          ? Colors.red.withOpacity(0.2)
                          : null;

              final textColor = parcelaPaga
                  ? Colors.green[800]
                  : (temAcordo && residualAtual != 0)
                      ? Colors.brown
                      : estaEmAtraso
                          ? Colors.red
                          : Colors.black87;

              final fontWeight = parcelaPaga
                  ? FontWeight.bold
                  : estaEmAtraso
                      ? FontWeight.bold
                      : FontWeight.normal;

              return DataRow(
                color: rowColor != null ? MaterialStateProperty.all(rowColor) : null,
                cells: [
                  DataCell(Text("${p['numero'] ?? ''}",
                      style: TextStyle(fontSize: 13, color: textColor, fontWeight: fontWeight))),
                  DataCell(TextField(
                    controller: c['vencimento'],
                    inputFormatters: [service.dateMaskFormatter()],
                    style: TextStyle(fontSize: 13, color: textColor, fontWeight: fontWeight),
                    decoration: const InputDecoration(
                        border: InputBorder.none, hintText: "dd/mm/aaaa"),
                  )),
                  DataCell(Focus(
                    onFocusChange: (hasFocus) {
                      if (!hasFocus) {
                        c['valor']!.text =
                            service.fmtMoeda(service.parseMoeda(c['valor']!.text));
                        setState(() {});
                      }
                    },
                    child: TextField(
                      controller: c['valor'],
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 13, color: textColor, fontWeight: fontWeight),
                      decoration: const InputDecoration(border: InputBorder.none),
                    ),
                  )),
                  DataCell(Focus(
                    onFocusChange: (hasFocus) {
                      if (!hasFocus) {
                        c['juros']!.text =
                            service.fmtMoeda(service.parseMoeda(c['juros']!.text));
                        setState(() {});
                      }
                    },
                    child: TextField(
                      controller: c['juros'],
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 13, color: textColor, fontWeight: fontWeight),
                      decoration: const InputDecoration(border: InputBorder.none),
                    ),
                  )),
                  DataCell(Focus(
                    onFocusChange: (hasFocus) {
                      if (!hasFocus) {
                        c['desconto']!.text =
                            service.fmtMoeda(service.parseMoeda(c['desconto']!.text));
                        setState(() {});
                      }
                    },
                    child: TextField(
                      controller: c['desconto'],
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 13, color: textColor, fontWeight: fontWeight),
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
                      style: TextStyle(fontSize: 13, color: textColor, fontWeight: fontWeight),
                      decoration: const InputDecoration(border: InputBorder.none),
                    ),
                  )),
                  DataCell(Focus(
                    onFocusChange: (hasFocus) {
                      if (!hasFocus) {
                        c['pg_juros']!.text =
                            service.fmtMoeda(service.parseMoeda(c['pg_juros']!.text));
                        setState(() {});
                      }
                    },
                    child: TextField(
                      controller: c['pg_juros'],
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 13, color: textColor, fontWeight: fontWeight),
                      decoration: const InputDecoration(border: InputBorder.none),
                    ),
                  )),
                  DataCell(Text(
                    service.fmtMoeda(
                      service.parseMoeda(c['pg_principal']!.text) +
                          service.parseMoeda(c['pg_juros']!.text),
                    ),
                    style: TextStyle(fontSize: 13, color: textColor, fontWeight: fontWeight),
                  )),
                  DataCell(Text(
                    service.fmtMoeda(residualAtual),
                    style: TextStyle(fontSize: 13, color: textColor, fontWeight: fontWeight),
                  )),
                  DataCell(TextField(
                    controller: c['data_pagamento'],
                    inputFormatters: [service.dateMaskFormatter()],
                    style: TextStyle(fontSize: 13, color: textColor, fontWeight: fontWeight),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "dd/mm/aaaa",
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: textColor,
                        fontWeight: fontWeight,
                      ),
                    ),
                  )),
                  DataCell(
                    Builder(builder: (context) {
                      final vencimentoTxt = p['vencimento']?.toString() ?? "";
                      DateTime? vencimento;
                      try {
                        // Agora o banco retorna "2025-10-03" (yyyy-MM-dd)
                        vencimento = DateTime.parse(vencimentoTxt);
                      } catch (_) {
                        vencimento = null;
                      }

                      final hoje = DateTime.now();
                      final limite = hoje.add(const Duration(days: 7));

                      final temAcordo = p['data_prevista'] != null &&
                          p['data_prevista'].toString().isNotEmpty;

                      final podeFazerAcordo = vencimento != null && 
                          vencimento.isBefore(limite.add(const Duration(days: 1)));

                      // 🔹 ALTERAÇÃO: Mantém o ícone visível mesmo quando a parcela está paga
                      // Apenas muda o comportamento do clique
                      if (temAcordo) {
                        return IconButton(
                          icon: const Icon(Icons.warning_amber_rounded,
                              color: Colors.orange, size: 22),
                          tooltip: residualAtual == 0 
                              ? "Acordo concluído (parcela paga)" 
                              : "Acordo ativo",
                          onPressed: () async {
                            final resultado = await abrirAcordoDialog(context, p);
                            if (resultado == true && mounted) {
                              setState(() {});
                            }
                          },
                        );
                      } else if (!podeFazerAcordo) {
                        return IconButton(
                          icon: const Icon(Icons.handshake, color: Colors.grey, size: 22),
                          tooltip: residualAtual == 0
                              ? "Parcela paga"
                              : "Só é possível criar acordo até 7 dias antes do vencimento",
                          onPressed: residualAtual == 0
                              ? null // Desabilita o clique se parcela paga
                              : () async {
                                  await showDialog(
                                    context: context,
                                    builder: (ctx) => const AlertDialog(
                                      content: Text(
                                        "Só é possível criar acordo para parcelas que estão vencendo nos próximos 7 dias.",
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                },
                        );
                      } else {
                        return IconButton(
                          icon: Icon(Icons.handshake, 
                              color: residualAtual == 0 ? Colors.green : Colors.blue, 
                              size: 22),
                          tooltip: residualAtual == 0
                              ? "Parcela paga - Clique para ver histórico"
                              : "Fazer acordo",
                          onPressed: () async {
                            final resultado = await abrirAcordoDialog(context, p);
                            if (resultado == true && mounted) {
                              setState(() {});
                            }
                          },
                        );
                      }
                    }),
                  ),
                ],
              );
            }),
            DataRow(cells: [
              const DataCell(Text("")),
              const DataCell(Text("TOTAL",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
              DataCell(Text(service.fmtMoeda(totalValor),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold))),
              DataCell(Text(service.fmtMoeda(totalJuros),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold))),
              DataCell(Text(service.fmtMoeda(totalDesconto),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold))),
              const DataCell(Text("")),
              DataCell(Text(service.fmtMoeda(totalPgPrincipal),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold))),
              DataCell(Text(service.fmtMoeda(totalPgJuros),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold))),
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
