import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
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

  final List<Map<String, TextEditingController>> _controllers = [];

  @override
  void initState() {
    super.initState();
    _parcelasFuture = _buscarParcelas();
  }

  Future<List<Map<String, dynamic>>> _buscarParcelas() async {
    final idEmprestimo =
        widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'];

    print(">>> [ParcelasPage] ID do empréstimo recebido: ${widget.emprestimo['id']}");
    print(">>> [ParcelasPage] ID do empréstimo recebido (id_emprestimo): ${widget.emprestimo['id_emprestimo']}");
    print(">>> [ParcelasPage] Usando ID do empréstimo para buscar: $idEmprestimo");

    if (idEmprestimo == null) {
      throw Exception("ID do empréstimo não informado.");
    }

    final response = await Supabase.instance.client
        .from('parcelas')
        .select()
        .eq('id_emprestimo', idEmprestimo)
        .order('numero', ascending: true);

    print(">>> [ParcelasPage] Resposta bruta do Supabase: $response");

    final parcelas =
        (response as List).map((e) => e as Map<String, dynamic>).toList();

    print(">>> [ParcelasPage] Quantidade de parcelas encontradas: ${parcelas.length}");
    for (var p in parcelas) {
      print(">>> [ParcelasPage] Parcela carregada: $p");
    }

    // 🔹 Calcula valor da parcela a partir do empréstimo
    final capital = num.tryParse("${widget.emprestimo["capital"]}") ?? 0;
    final juros = num.tryParse("${widget.emprestimo["juros"]}") ?? 0;
    final qtdParcelas = num.tryParse("${widget.emprestimo["meses"]}") ?? 1;

    final valorParcela = (capital + juros) / qtdParcelas;

    // 🔹 Ajusta campos das parcelas
    for (final p in parcelas) {
      p['valor'] = valorParcela;
      p['pg_principal'] ??= valorParcela - juros;
      p['pg_juros'] ??= juros / qtdParcelas;
    }

    // 🔹 Preenche os controladores
    _controllers.clear();
    for (final p in parcelas) {
      _controllers.add({
        'vencimento':
            TextEditingController(text: p['vencimento']?.toString() ?? ''),
        'valor': TextEditingController(text: fmtMoeda(p['valor'])),
        'juros': TextEditingController(text: fmtMoeda(p['juros'])),
        'desconto': TextEditingController(text: fmtMoeda(p['desconto'])),
        'pg_principal':
            TextEditingController(text: fmtMoeda(p['pg_principal'])),
        'pg_juros': TextEditingController(text: fmtMoeda(p['pg_juros'])),
        'data_pagamento':
            TextEditingController(text: p['data_pagamento']?.toString() ?? ''),
      });
    }

    return parcelas;
  }


  String fmtMoeda(dynamic valor) {
    if (valor == null) return "";
    final txt = valor.toString().trim();
    if (txt.isEmpty) return "";
    if (txt.startsWith("R\$")) return txt;
    final numero = num.tryParse(txt.replaceAll(",", "."));
    if (numero == null || numero == 0) return "";
    return _formatter.format(numero);
  }

  double parseMoeda(String txt) {
    if (txt.isEmpty) return 0;
    return double.tryParse(
            txt.replaceAll("R\$", "").replaceAll(".", "").replaceAll(",", ".")
                .trim()) ??
        0;
  }  

  Future<void> salvarParcelasNoSupabase(
      String emprestimoId, String usuarioId, List<Map<String, dynamic>> parcelas) async {
    final supabase = Supabase.instance.client;

    try {
      // 🔹 Remove todas as parcelas antigas do empréstimo
      await supabase
          .from('parcelas')
          .delete()
          .eq('id_emprestimo', emprestimoId)
          .eq('id_usuario', usuarioId);

      // 🔹 Insere as novas parcelas
      await supabase.from('parcelas').insert(parcelas);

      print("Parcelas salvas no Supabase!");
    } catch (e) {
      print("Erro ao salvar parcelas: $e");
      rethrow;
    }
  }

  /// 🔹 Formatter simples para dd/mm/aaaa
  TextInputFormatter dateMaskFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (text.length > 8) text = text.substring(0, 8);

      String formatted = '';
      for (int i = 0; i < text.length; i++) {
        formatted += text[i];
        if (i == 1 || i == 3) formatted += '/';
      }

      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }



  @override
  Widget build(BuildContext context) {
    final valor = num.tryParse("${widget.emprestimo["valor"]}") ?? 0;
    final parcelas = widget.emprestimo["parcelas"]?.toString() ?? "0";
    final cliente = widget.emprestimo["cliente"] ?? "";
    final numero = widget.emprestimo["numero"] ?? "";
    final dataInicio = widget.emprestimo["data_inicio"] ?? "";
    final capital = num.tryParse("${widget.emprestimo["capital"]}") ?? 0;
    final juros = num.tryParse("${widget.emprestimo["juros"]}") ?? 0;
    final meses = widget.emprestimo["meses"]?.toString() ?? "0";
    final prestacao = num.tryParse("${widget.emprestimo["prestacao"]}") ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text("Parcelas - $cliente"),
      ),
      body: Container(
        color: const Color(0xFFFAF9F6),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Resumo no padrão da tela Financeiro
            Text(
              "Nº $numero  |  Data do empréstimo: $dataInicio\n"
              "Capital: ${fmtMoeda(valor)} | Juros: ${fmtMoeda(juros)} | "
              "Montante: ${fmtMoeda(valor + juros)} | "
              "$parcelas parcelas de ${fmtMoeda(prestacao)}",
              style: const TextStyle(color: Colors.black87, fontSize: 14),
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
                      child: Text("Erro: ${snapshot.error}",
                          style: const TextStyle(color: Colors.red)),
                    );
                  }

                  final parcelas = snapshot.data ?? [];
                  if (parcelas.isEmpty) {
                    return const Center(
                      child: Text("Nenhuma parcela encontrada.",
                          style: TextStyle(color: Colors.black87)),
                    );
                  }

                  // 🔹 Totais
                  double totalValor = 0;
                  double totalJuros = 0;
                  double totalDesconto = 0;
                  double totalPgPrincipal = 0;
                  double totalPgJuros = 0;

                  for (var i = 0; i < parcelas.length; i++) {
                    totalValor += parseMoeda(_controllers[i]['valor']!.text);
                    totalJuros += parseMoeda(_controllers[i]['juros']!.text);
                    totalDesconto += parseMoeda(_controllers[i]['desconto']!.text);
                    totalPgPrincipal += parseMoeda(_controllers[i]['pg_principal']!.text);
                    totalPgJuros += parseMoeda(_controllers[i]['pg_juros']!.text);
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
                        dataTextStyle:
                            const TextStyle(color: Colors.black87, fontSize: 13),
                        columns: const [
                          DataColumn(
                            label: SizedBox(width: 40, child: Align(alignment: Alignment.center, child: Text("Nº", textAlign: TextAlign.center))),
                          ),
                          DataColumn(
                            label: SizedBox(width: 85, child: Align(alignment: Alignment.center, child: Text("Vencimento", textAlign: TextAlign.center))),
                          ),
                          DataColumn(
                            label: SizedBox(width: 95, child: Align(alignment: Alignment.center, child: Text("Valor", textAlign: TextAlign.center))),
                          ),
                          DataColumn(
                            label: SizedBox(width: 95, child: Align(alignment: Alignment.center, child: Text("Juros", textAlign: TextAlign.center))),
                          ),
                          DataColumn(
                            label: SizedBox(width: 95, child: Align(alignment: Alignment.center, child: Text("Desconto", textAlign: TextAlign.center))),
                          ),
                          DataColumn(
                            label: SizedBox(width: 55, child: Align(alignment: Alignment.center, child: Text("Calc.", textAlign: TextAlign.center))),
                          ),
                          DataColumn(
                            label: SizedBox(width: 95, child: Align(alignment: Alignment.center, child: Text("Pg. Principal", textAlign: TextAlign.center))),
                          ),
                          DataColumn(
                            label: SizedBox(width: 95, child: Align(alignment: Alignment.center, child: Text("Pg. Juros", textAlign: TextAlign.center))),
                          ),
                          DataColumn(
                            label: SizedBox(width: 95, child: Align(alignment: Alignment.center, child: Text("Valor Pago", textAlign: TextAlign.center))),
                          ),
                          DataColumn(
                            label: SizedBox(width: 95, child: Align(alignment: Alignment.center, child: Text("Saldo", textAlign: TextAlign.center))),
                          ),
                          DataColumn(
                            label: SizedBox(width: 85, child: Align(alignment: Alignment.center, child: Text("Data Pag.", textAlign: TextAlign.center))),
                          ),
                          DataColumn(
                            label: SizedBox(width: 55, child: Align(alignment: Alignment.center, child: Text("Ações", textAlign: TextAlign.center))),
                          ),
                        ],
                        rows: [
                          ...List.generate(parcelas.length, (i) {
                            final p = parcelas[i];
                            final c = _controllers[i];

                            return DataRow(cells: [
                              DataCell(SizedBox(
                                width: 40,
                                child: Text("${p['numero'] ?? ''}",
                                    style: const TextStyle(fontSize: 13)),
                              )),

                              DataCell(SizedBox(
                                width: 85,
                                child: TextField(
                                  controller: c['vencimento'],
                                  inputFormatters: [dateMaskFormatter()],
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none, hintText: "dd/mm/aaaa"),
                                ),
                              )),

                              DataCell(SizedBox(
                                width: 95,
                                child: Focus(
                                  onFocusChange: (hasFocus) {
                                    if (!hasFocus) {
                                      c['valor']!.text = fmtMoeda(parseMoeda(c['valor']!.text));
                                      setState(() {});
                                    }
                                  },
                                  child: TextField(
                                    controller: c['valor'],
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(border: InputBorder.none),
                                  ),
                                ),
                              )),

                              DataCell(SizedBox(
                                width: 95,
                                child: Focus(
                                  onFocusChange: (hasFocus) {
                                    if (!hasFocus) {
                                      c['juros']!.text = fmtMoeda(parseMoeda(c['juros']!.text));
                                      setState(() {});
                                    }
                                  },
                                  child: TextField(
                                    controller: c['juros'],
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(border: InputBorder.none),
                                  ),
                                ),
                              )),

                              DataCell(SizedBox(
                                width: 95,
                                child: Focus(
                                  onFocusChange: (hasFocus) {
                                    if (!hasFocus) {
                                      c['desconto']!.text = fmtMoeda(parseMoeda(c['desconto']!.text));
                                      setState(() {});
                                    }
                                  },
                                  child: TextField(
                                    controller: c['desconto'],
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(border: InputBorder.none),
                                  ),
                                ),
                              )),

                              DataCell(SizedBox(
                                width: 55,
                                child: IconButton(
                                  icon: const Icon(Icons.calculate, size: 20, color: Colors.blue),
                                  onPressed: () {
                                    final capital = num.tryParse("${widget.emprestimo["valor"]}") ?? 0;
                                    final jurosSupabase =
                                        num.tryParse("${widget.emprestimo["juros"]}") ?? 0;
                                    final parcelas =
                                        num.tryParse("${widget.emprestimo["parcelas"]}") ?? 1;
                                    final jurosDigitado = parseMoeda(c['juros']!.text);
                                    final desconto = parseMoeda(c['desconto']!.text);

                                    final pgPrincipal = capital / parcelas;
                                    final pgJuros = jurosSupabase / parcelas + jurosDigitado - desconto;

                                    c['pg_principal']!.text = fmtMoeda(pgPrincipal);
                                    c['pg_juros']!.text = fmtMoeda(pgJuros);

                                    setState(() {});
                                  },
                                ),
                              )),

                              DataCell(SizedBox(
                                width: 95,
                                child: TextField(
                                  controller: c['pg_principal'],
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(border: InputBorder.none),
                                ),
                              )),

                              DataCell(SizedBox(
                                width: 95,
                                child: TextField(
                                  controller: c['pg_juros'],
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(border: InputBorder.none),
                                ),
                              )),

                              DataCell(SizedBox(
                                width: 95,
                                child: Text(
                                  fmtMoeda(
                                    parseMoeda(c['pg_principal']!.text) +
                                    parseMoeda(c['pg_juros']!.text),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              )),

                              DataCell(SizedBox(
                                width: 95,
                                child: Text(
                                  fmtMoeda(
                                    parseMoeda(c['valor']!.text) +
                                    parseMoeda(c['juros']!.text) -
                                    parseMoeda(c['desconto']!.text) -
                                    (parseMoeda(c['pg_principal']!.text) +
                                    parseMoeda(c['pg_juros']!.text)),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              )),

                              DataCell(SizedBox(
                                width: 85,
                                child: TextField(
                                  controller: c['data_pagamento'],
                                  inputFormatters: [dateMaskFormatter()],
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none, hintText: "dd/mm/aaaa"),
                                ),
                              )),

                              DataCell(SizedBox(
                                width: 55,
                                child: IconButton(
                                  icon: const Text("🤝", style: TextStyle(fontSize: 20)),
                                  tooltip: "Fazer acordo",
                                  onPressed: () {
                                    _abrirAcordoDialog(context, p);
                                  },
                                ),
                              )),
                            ]);
                          }),

                          // Linha TOTAL com "TOTAL" na coluna Vencimento
                          DataRow(cells: [
                            const DataCell(Text("")), // col Nº fica vazia
                            DataCell(SizedBox(
                              width: 85,
                              child: const Center(
                                child: Text(
                                  "TOTAL",
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                            )),
                            DataCell(SizedBox(
                              width: 95,
                              child: Text(fmtMoeda(totalValor),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            )),
                            DataCell(SizedBox(
                              width: 95,
                              child: Text(fmtMoeda(totalJuros),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            )),
                            DataCell(SizedBox(
                              width: 95,
                              child: Text(fmtMoeda(totalDesconto),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            )),
                            const DataCell(Text("")), // Calc.
                            DataCell(SizedBox(
                              width: 95,
                              child: Text(fmtMoeda(totalPgPrincipal),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            )),
                            DataCell(SizedBox(
                              width: 95,
                              child: Text(fmtMoeda(totalPgJuros),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            )),
                            const DataCell(Text("")), // Valor Pago
                            const DataCell(Text("")), // Saldo
                            const DataCell(Text("")), // Data Pag.
                            const DataCell(Text("")), // Ações
                          ]),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () async {
                final parcelas = await _parcelasFuture;

                final parcelasAtualizadas = <Map<String, dynamic>>[];
                for (int i = 0; i < parcelas.length; i++) {
                  final p = parcelas[i];
                  final c = _controllers[i];

                  parcelasAtualizadas.add({
                    'id': p['id'],
                    'id_emprestimo': widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'],
                    'numero': p['numero'],
                    'vencimento': c['vencimento']!.text,
                    'valor': parseMoeda(c['valor']!.text),
                    'juros': parseMoeda(c['juros']!.text),
                    'desconto': parseMoeda(c['desconto']!.text),
                    'pg_principal': parseMoeda(c['pg_principal']!.text),
                    'pg_juros': parseMoeda(c['pg_juros']!.text),
                    'valor_pago': (parseMoeda(c['pg_principal']!.text) +
                        parseMoeda(c['pg_juros']!.text)),
                    'residual': (parseMoeda(c['valor']!.text) +
                        parseMoeda(c['juros']!.text) -
                        parseMoeda(c['desconto']!.text) -
                        (parseMoeda(c['pg_principal']!.text) +
                            parseMoeda(c['pg_juros']!.text))),
                    'data_pagamento': c['data_pagamento']!.text,
                    'id_usuario': widget.emprestimo['id_usuario'],
                  });
                }

                // 🔹 Atualiza cada parcela no Supabase mantendo o mesmo id
                await Future.wait(parcelasAtualizadas.map((p) async {
                  final id = p['id'];
                  if (id == null) return;

                  // remove id para não tentar atualizar a PK
                  final dadosAtualizados = Map<String, dynamic>.from(p)..remove('id');

                  await Supabase.instance.client
                      .from('parcelas')
                      .update(dadosAtualizados)
                      .eq('id', id);
                }));

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Parcelas salvas com sucesso!")),
                );
              },
              icon: const Icon(Icons.save),
              label: const Text("Salvar Parcelas"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _abrirAcordoDialog(BuildContext context, Map<String, dynamic> parcela) async {
    final comentarioCtrl = TextEditingController(text: parcela["comentario"] ?? "");
    DateTime? dataPrevista = parcela["data_prevista"] != null && parcela["data_prevista"].toString().isNotEmpty
        ? DateFormat("dd/MM/yyyy").parse(parcela["data_prevista"])
        : null;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🤝 Fazer acordo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: comentarioCtrl,
              maxLength: 100,
              decoration: const InputDecoration(labelText: "Comentário"),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: dataPrevista ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  dataPrevista = picked;
                }
              },
              child: Text(
                dataPrevista == null
                    ? "Selecionar data prevista"
                    : DateFormat("dd/MM/yyyy").format(dataPrevista!),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          if (parcela["data_prevista"] != null && parcela["data_prevista"].toString().isNotEmpty)
            TextButton(
              onPressed: () async {
                await Supabase.instance.client
                    .from("parcelas")
                    .update({"data_prevista": null, "comentario": null})
                    .eq("id", parcela["id"]);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Acordo excluído!")),
                );
              },
              child: const Text("Excluir acordo", style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () async {
              if (dataPrevista == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Escolha uma data prevista.")),
                );
                return;
              }
              await Supabase.instance.client
                  .from("parcelas")
                  .update({
                    "data_prevista": DateFormat("dd/MM/yyyy").format(dataPrevista!),
                    "comentario": comentarioCtrl.text,
                  })
                  .eq("id", parcela["id"]);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Acordo salvo com sucesso!")),
              );
            },
            child: const Text("Salvar acordo"),
          ),
        ],
      ),
    );
  }
}