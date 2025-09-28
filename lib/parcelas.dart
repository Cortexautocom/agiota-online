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
    if (idEmprestimo == null) {
      throw Exception("ID do empréstimo não informado.");
    }

    final response = await Supabase.instance.client
        .from('parcelas')
        .select()
        .eq('id_emprestimo', idEmprestimo)
        .order('numero', ascending: true);

    final parcelas =
        (response as List).map((e) => e as Map<String, dynamic>).toList();

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
        'data_pag':
            TextEditingController(text: p['data_pag']?.toString() ?? ''),
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

  Future<void> _salvarParcelas(List<Map<String, dynamic>> parcelas) async {
    try {
      for (int i = 0; i < parcelas.length; i++) {
        final p = parcelas[i];
        final c = _controllers[i];

        final atualizada = {
          'vencimento': c['vencimento']!.text,
          'valor': c['valor']!.text,
          'juros': c['juros']!.text,
          'desconto': c['desconto']!.text,
          'pg_principal': c['pg_principal']!.text,
          'pg_juros': c['pg_juros']!.text,
          'data_pag': c['data_pag']!.text,
        };

        await Supabase.instance.client
            .from('parcelas')
            .update(atualizada)
            .eq('id', p['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Parcelas salvas com sucesso!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar parcelas: $e")),
        );
      }
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
              "Montante: ${fmtMoeda(capital)} | $meses parcelas de ${fmtMoeda(prestacao)}",
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
                    totalDesconto +=
                        parseMoeda(_controllers[i]['desconto']!.text);
                    totalPgPrincipal +=
                        parseMoeda(_controllers[i]['pg_principal']!.text);
                    totalPgJuros +=
                        parseMoeda(_controllers[i]['pg_juros']!.text);
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          MaterialStateProperty.all(Colors.grey[300]),
                      headingTextStyle: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold),
                      dataTextStyle:
                          const TextStyle(color: Colors.black87, fontSize: 13),
                      columns: const [
                        DataColumn(label: Text("Nº")),
                        DataColumn(label: Text("Vencimento")),
                        DataColumn(label: Text("Valor")),
                        DataColumn(label: Text("Juros")),
                        DataColumn(label: Text("Desconto")),
                        DataColumn(label: Text("Calc.")),
                        DataColumn(label: Text("Pg. Principal")),
                        DataColumn(label: Text("Pg. Juros")),
                        DataColumn(label: Text("Valor Pago")),
                        DataColumn(label: Text("Saldo")),
                        DataColumn(label: Text("Data Pag.")),
                      ],
                      rows: [
                        ...List.generate(parcelas.length, (i) {
                          final p = parcelas[i];
                          final c = _controllers[i];

                          return DataRow(cells: [
                            DataCell(Text("${p['numero'] ?? ''}",
                                style: const TextStyle(fontSize: 13))),
                            DataCell(TextField(
                              controller: c['vencimento'],
                              inputFormatters: [dateMaskFormatter()],
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                  border: InputBorder.none, hintText: "dd/mm/aaaa"),
                            )),
                            DataCell(Focus(
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
                            )),
                            DataCell(Focus(
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
                            )),
                            DataCell(Focus(
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
                            )),
                            const DataCell(Text("")),
                            DataCell(Focus(
                              onFocusChange: (hasFocus) {
                                if (!hasFocus) {
                                  c['pg_principal']!.text =
                                      fmtMoeda(parseMoeda(c['pg_principal']!.text));
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
                                  c['pg_juros']!.text = fmtMoeda(parseMoeda(c['pg_juros']!.text));
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
                            DataCell(Text(fmtMoeda(p['valor_pago']),
                                style: const TextStyle(fontSize: 13))),
                            DataCell(Text(fmtMoeda(p['saldo']),
                                style: const TextStyle(fontSize: 13))),
                            DataCell(TextField(
                              controller: c['data_pag'],
                              inputFormatters: [dateMaskFormatter()],
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                  border: InputBorder.none, hintText: "dd/mm/aaaa"),
                            )),
                          ]);
                        }),

                        // 🔹 Totalizadores
                        DataRow(cells: [
                          const DataCell(Text("TOTAL",
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold))),
                          const DataCell(Text("")),
                          DataCell(Text(fmtMoeda(totalValor),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold))),
                          DataCell(Text(fmtMoeda(totalJuros),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold))),
                          DataCell(Text(fmtMoeda(totalDesconto),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold))),
                          const DataCell(Text("")),
                          DataCell(Text(fmtMoeda(totalPgPrincipal),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold))),
                          DataCell(Text(fmtMoeda(totalPgJuros),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold))),
                          const DataCell(Text("")),
                          const DataCell(Text("")),
                          const DataCell(Text("")),
                        ]),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () async {
                final parcelas = await _parcelasFuture;
                _salvarParcelas(parcelas);
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
}
