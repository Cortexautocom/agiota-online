import 'package:flutter/material.dart';
import 'parcelas_service.dart';
import 'acordo_dialog.dart';
//import 'package:intl/intl.dart';
import 'utils.dart';
import 'parcelas_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // 🔹 MÉTODO PARA ADICIONAR NOVA PARCELA
  void adicionarNovaParcela() {
    final novaParcela = {
      'id': '', // Será gerado pelo banco
      'numero': widget.parcelas.length + 1,
      'vencimento': '',
      'valor': 0.0,
      'juros': 0.0,
      'desconto': 0.0,
      'pg_principal': 0.0,
      'pg_juros': 0.0,
      'data_pagamento': '',
      'valor_pago': 0.0,
      'residual': 0.0,
      'data_prevista': null,
    };

    setState(() {
      widget.parcelas.add(novaParcela);
      _controllers.add({
        'vencimento': TextEditingController(),
        'valor': TextEditingController(text: '0,00'),
        'juros': TextEditingController(text: '0,00'),
        'desconto': TextEditingController(text: '0,00'),
        'pg_principal': TextEditingController(text: '0,00'),
        'pg_juros': TextEditingController(text: '0,00'),
        'data_pagamento': TextEditingController(),
      });
    });
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
    
  /// 🔹 MÉTODO NOVO: Remover parcela
  void _removerParcela(int index) {
    if (widget.parcelas.length <= 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          content: const Text(
            "Não é possível remover a única parcela restante.",
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
      return;
    }

    setState(() {
      widget.parcelas.removeAt(index);
      _controllers.removeAt(index);
      
      // 🔹 Reorganiza os números das parcelas
      for (int i = 0; i < widget.parcelas.length; i++) {
        widget.parcelas[i]['numero'] = i + 1;
      }
    });
  }

  /// 🔹 Coleta os valores editados e salva no Supabase (ATUALIZADO)
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

        
        if (residual < 1.00 && dataPag.isEmpty) {
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

        if ((residual.abs() > 1.00) && (residual.abs() < (valorTotalOriginal - 1.00))) {
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

        // 🔹 DADOS BASE PARA TODAS AS PARCELAS
        final dadosParcela = {
          'id_emprestimo': widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'],
          'numero': p['numero'],
          'vencimento': _toIsoDate(c['vencimento']!.text),
          'valor': valor,
          'juros': juros,
          'desconto': desconto,
          'pg_principal': pgPrincipal,
          'pg_juros': pgJuros,
          'valor_pago': valorPago,
          'residual': residual,
          'data_pagamento': _toIsoDate(dataPag),
          'id_usuario': widget.emprestimo['id_usuario'],
          'data_prevista': p['data_prevista'], // Mantém acordo se existir
        };

        // 🔹 DIFERENCIAR ENTRE ATUALIZAÇÃO E CRIAÇÃO
        if (p['id'] != null && p['id'] != '') {
          // 🔹 PARCELA EXISTENTE - inclui o ID
          parcelasAtualizadas.add({
            'id': p['id'],
            ...dadosParcela
          });
        } else {
          // 🔹 NOVA PARCELA - sem ID (será gerado pelo banco)
          parcelasAtualizadas.add(dadosParcela);
        }
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

    // ✅ CORREÇÃO: Só calcula totais se houver parcelas
    if (widget.parcelas.isNotEmpty && _controllers.isNotEmpty) {
      for (var i = 0; i < widget.parcelas.length; i++) {
        totalValor += service.parseMoeda(_controllers[i]['valor']!.text);
        totalJuros += service.parseMoeda(_controllers[i]['juros']!.text);
        totalDesconto += service.parseMoeda(_controllers[i]['desconto']!.text);
        totalPgPrincipal += service.parseMoeda(_controllers[i]['pg_principal']!.text);
        totalPgJuros += service.parseMoeda(_controllers[i]['pg_juros']!.text);
      }
    }

    return Column(
      children: [                
        // 🔹 TABELA ATUAL (com novas funcionalidades)
        SingleChildScrollView(
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
                DataColumn(label: SizedBox(width: 20, child: Text("Nº"))),
                DataColumn(label: SizedBox(width: 100, child: Text("Vencimento"))),
                DataColumn(label: SizedBox(width: 90, child: Text("     Valor"))),
                DataColumn(label: SizedBox(width: 80, child: Text("Juros"))),
                DataColumn(label: SizedBox(width: 90, child: Text("Desconto"))),
                DataColumn(label: SizedBox(width: 110, child: Text("Pg. Principal"))),
                DataColumn(label: SizedBox(width: 100, child: Text("Pg. Juros"))),
                DataColumn(label: SizedBox(width: 100, child: Text("Valor Pago"))),
                DataColumn(label: SizedBox(width: 100, child: Text("    Saldo"))),
                DataColumn(label: SizedBox(width: 110, child: Text("  Data Pag."))),
                DataColumn(label: Center(child: SizedBox(width: 50, child: Text("Acordo")),),),                  
                DataColumn(label: SizedBox(width: 5, child: Text(""))), // 🔹 COLUNA NOVA
              ],              
              rows: widget.parcelas.isNotEmpty ? [
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
                  final bool parcelaPaga = residualAtual <= 1.00;

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
                      : (temAcordo && residualAtual > 1.00)
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
                      DataCell(
                        SizedBox(
                          width: 20, // Largura
                          child: Center(
                            child: Text(
                              "${p['numero'] ?? ''}",
                              style: TextStyle(
                                fontSize: 13,
                                color: textColor,
                                fontWeight: fontWeight,
                              ),
                            ),
                          ),
                        ),
                      ),
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
                        SizedBox(
                          width: 50, // largura acordo
                          child: Center(
                            child: Builder(
                              builder: (context) {
                                // (mantém toda a lógica interna igual)
                                final vencimentoTxt = p['vencimento']?.toString() ?? "";
                                DateTime? vencimento;
                                try {
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

                                if (temAcordo) {
                                  return IconButton(
                                    icon: const Icon(Icons.warning_amber_rounded,
                                        color: Colors.orange, size: 22),
                                    tooltip: residualAtual <= 1.00
                                        ? "Acordo concluído (parcela paga)"
                                        : "Acordo ativo",
                                    onPressed: () async {
                                      final parcelaAtualizada = await Supabase.instance.client
                                          .from("parcelas")
                                          .select()
                                          .eq("id", p['id'])
                                          .single();

                                      final resultado = await abrirAcordoDialog(
                                          context, parcelaAtualizada, widget.emprestimo);

                                      if (resultado == true && mounted) {
                                        final state =
                                            context.findAncestorStateOfType<ParcelasPageState>();
                                        if (state != null && state.mounted) {
                                          await state.atualizarParcelas();
                                        }
                                        setState(() {});
                                      }
                                    },
                                  );
                                } else if (!podeFazerAcordo) {
                                  return IconButton(
                                    icon: const Icon(Icons.handshake, color: Colors.grey, size: 22),
                                    tooltip: residualAtual < 1.00
                                        ? "Parcela paga"
                                        : "Só é possível criar acordo até 7 dias antes do vencimento",
                                    onPressed: residualAtual == 0
                                        ? null
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
                                  final parcelasVencidas = widget.parcelas.where((parcela) {
                                    try {
                                      final v = DateTime.parse(parcela['vencimento'].toString());

                                      // 🔹 Calcula residual atualizado com os mesmos critérios visuais
                                      final residualAtualTemp = (parcela['valor'] ?? 0).toDouble() +
                                          (parcela['juros'] ?? 0).toDouble() -
                                          (parcela['desconto'] ?? 0).toDouble() -
                                          ((parcela['pg_principal'] ?? 0).toDouble() +
                                              (parcela['pg_juros'] ?? 0).toDouble());

                                      // 🔹 Só considera "vencida" se for anterior a hoje e residual > 1,00
                                      return v.isBefore(DateTime.now()) && residualAtualTemp > 1.00;
                                    } catch (_) {
                                      return false;
                                    }
                                  }).toList();

                                  parcelasVencidas.sort((a, b) =>
                                      DateTime.parse(a['vencimento'].toString())
                                          .compareTo(DateTime.parse(b['vencimento'].toString())));

                                  final ultimaVencida = parcelasVencidas.isNotEmpty
                                      ? parcelasVencidas.last
                                      : null;

                                  final bool naoEhUltimaVencida =
                                      ultimaVencida != null && ultimaVencida['id'] != p['id'];

                                  if (naoEhUltimaVencida) {
                                    // ❌ Bloqueia criação de acordo nesta parcela
                                    return IconButton(
                                      icon: const Icon(Icons.handshake, color: Colors.grey, size: 22),
                                      tooltip: "Acordo disponível apenas para a última parcela em atraso.",
                                      onPressed: () async {
                                        await showDialog(
                                          context: context,
                                          builder: (ctx) => const AlertDialog(
                                            content: Text(
                                              "Não é possível criar acordo nesta parcela.\n\n"
                                              "Existe uma parcela posterior em atraso.\n"
                                              "Crie o acordo apenas na última vencida.",
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  } else {
                                    // ✅ Pode criar o acordo normalmente
                                    return IconButton(
                                      icon: Icon(
                                        Icons.handshake,
                                        color: residualAtual < 1.00 ? Colors.green : Colors.blue,
                                        size: 22,
                                      ),
                                      tooltip: residualAtual < 1.00
                                          ? "Parcela paga - Clique para ver histórico"
                                          : "Acordo",
                                      onPressed: () async {
                                        final parcelaAtualizada = await Supabase.instance.client
                                            .from("parcelas")
                                            .select()
                                            .eq("id", p['id'])
                                            .single();

                                        final resultado = await abrirAcordoDialog(
                                            context, parcelaAtualizada, widget.emprestimo);

                                        if (resultado == true && mounted) {
                                          final state = context.findAncestorStateOfType<ParcelasPageState>();
                                          if (state != null && state.mounted) {
                                            await state.atualizarParcelas();
                                          }
                                          setState(() {});
                                        }
                                      },
                                    );
                                  }

                                }
                              },
                            ),
                          ),
                        ),
                      ),


                      // 🔹 CÉLULA NOVA: Menu de ações com 3 pontinhos
                      DataCell(
                        SizedBox(
                          width: 20, // 👈 define largura mínima da célula
                          child: Center(
                            child: PopupMenuButton<String>(
                              padding: EdgeInsets.zero, // 👈 remove margens internas
                              icon: const Icon(Icons.more_vert, color: Colors.black54, size: 22),
                              tooltip: 'Ações',
                              onSelected: (value) {
                                if (value == 'excluir') {
                                  _removerParcela(i);
                                } else if (value == 'calcular') {
                                  // 🔹 Lógica de cálculo automático (igual ao botão antigo)
                                  final capital = num.tryParse("${widget.emprestimo["valor"]}") ?? 0;
                                  final jurosSupabase = num.tryParse("${widget.emprestimo["juros"]}") ?? 0;
                                  final qtdParcelas = num.tryParse("${widget.emprestimo["parcelas"]}") ?? 1;
                                  final jurosDigitado = service.parseMoeda(c['juros']!.text);
                                  final desconto = service.parseMoeda(c['desconto']!.text);

                                  final pgPrincipal = capital / qtdParcelas;
                                  final pgJuros = jurosSupabase / qtdParcelas + jurosDigitado - desconto;

                                  c['pg_principal']!.text = service.fmtMoeda(pgPrincipal);
                                  c['pg_juros']!.text = service.fmtMoeda(pgJuros);

                                  setState(() {});
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem<String>(
                                  value: 'calcular',
                                  child: Row(
                                    children: [
                                      Icon(Icons.calculate, color: Colors.blue, size: 18),
                                      SizedBox(width: 8),
                                      Text('Lançamento automático'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'excluir',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red, size: 18),
                                      SizedBox(width: 8),
                                      Text('Excluir parcela'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                // 🔹 LINHA DE TOTAIS - SÓ MOSTRA SE HOUVER PARCELAS
                if (widget.parcelas.isNotEmpty) 
                  DataRow(
                    color: MaterialStateProperty.all(Colors.grey[200]),
                    cells: [
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
                      const DataCell(Text("")), // 🔹 coluna Ações
                    ],
                  ),
              ] : [ // ← CORREÇÃO: espaço antes dos dois pontos
                // 🔹 MENSAGEM QUANDO NÃO HÁ PARCELAS
                DataRow(
                  cells: [
                    DataCell(SizedBox(
                      width: MediaQuery.of(context).size.width - 100,
                      child: const Center(
                        child: Text(
                          "Nenhuma parcela cadastrada. Clique em 'Adicionar Parcela' para começar.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )),
                    // Células vazias para as outras colunas
                    DataCell(Container()), DataCell(Container()), DataCell(Container()),
                    DataCell(Container()), DataCell(Container()), DataCell(Container()),
                    DataCell(Container()), DataCell(Container()), DataCell(Container()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}