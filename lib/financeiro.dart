import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas_page.dart';
import 'emprestimo_form.dart';
import 'utils.dart'; // 🔹 função fmtMoeda
import 'package:intl/intl.dart';
import 'garantias.dart';
import 'arquivados_page.dart';

class FinanceiroPage extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const FinanceiroPage({super.key, required this.cliente});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  Future<Map<String, String>> _calcularDatas(String idEmprestimo) async {
    final parcelas = await Supabase.instance.client
        .from('parcelas')
        .select()
        .eq('id_emprestimo', idEmprestimo);

    DateTime? proxima;
    DateTime? ultima;
    int pagas = 0;
    int abertas = 0;

    for (final p in parcelas) {
      final vencTxt = p['vencimento']?.toString() ?? "";
      if (vencTxt.isEmpty) continue;
      final venc = DateTime.tryParse(vencTxt); // ✅ usar ISO direto
      if (venc == null) continue;

      final residual = num.tryParse("${p['residual']}") ?? 0;

      if (residual == 0) {
        pagas++;
      } else {
        abertas++;
        if (proxima == null || venc.isBefore(proxima)) {
          proxima = venc;
        }
      }

      if (ultima == null || venc.isAfter(ultima)) {
        ultima = venc;
      }
    }

    final temAcordo = parcelas.any((p) {
      final vencTxt = p['vencimento']?.toString() ?? "";
      if (vencTxt.isEmpty) return false;
      final venc = DateTime.tryParse(vencTxt);
      final residual = num.tryParse("${p['residual']}") ?? 0;
      final dataPrevista = p['data_prevista']?.toString().trim() ?? "";

      return residual > 0 &&
          venc != null &&
          proxima != null &&
          venc.isAtSameMomentAs(proxima) &&
          dataPrevista.isNotEmpty;
    });

    return {
      "proxima": proxima != null ? DateFormat("dd/MM/yyyy").format(proxima) : "-",
      "ultima": ultima != null ? DateFormat("dd/MM/yyyy").format(ultima) : "-",
      "situacao": "$pagas parcelas pagas, $abertas parcelas restando.",
      "acordo": temAcordo ? "sim" : "nao",
    };
  }

  @override
  Widget build(BuildContext context) {
    final cliente = widget.cliente;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Financeiro - ${cliente['nome']}"),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: Colors.grey[200],
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black54,
                indicator: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(child: SizedBox(height: 32, child: Center(child: Text("Empréstimos")))),
                  Tab(child: SizedBox(height: 32, child: Center(child: Text("Garantias")))),
                  Tab(child: SizedBox(height: 32, child: Center(child: Text("Arquivados")))),
                ],
              ),
            ),
          ),
        ),

        body: TabBarView(
          children: [
            // 🔹 Aba 1: Empréstimos Ativos
            Container(
              color: const Color(0xFFFAF9F6),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Empréstimos do Cliente",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: Stack(
                      children: [
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: Supabase.instance.client
                              .from('emprestimos')
                              .select()
                              .eq('id_cliente', cliente['id_cliente'])
                              .eq('ativo', 'sim')
                              .order('data_inicio'),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text("Erro: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
                              );
                            }

                            final emprestimos = (snapshot.data as List?)
                                    ?.map((e) => e as Map<String, dynamic>)
                                    .toList() ??
                                [];

                            if (emprestimos.isEmpty) {
                              return const Center(
                                child: Text("Nenhum empréstimo encontrado.", style: TextStyle(color: Colors.black87)),
                              );
                            }

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  headingRowColor: MaterialStateProperty.all(Colors.grey[300]),
                                  headingTextStyle: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  dataTextStyle: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13,
                                  ),
                                  columns: const [
                                    DataColumn(label: SizedBox(width: 160, child: Center(child: Text("Cliente")))),
                                    DataColumn(label: SizedBox(width: 100, child: Center(child: Text("Nº Empr.")))),
                                    DataColumn(label: SizedBox(width: 100, child: Center(child: Text("Data Início")))),
                                    DataColumn(label: SizedBox(width: 110, child: Center(child: Text("Último venc.")))),
                                    DataColumn(label: SizedBox(width: 110, child: Center(child: Text("Capital")))),
                                    DataColumn(label: SizedBox(width: 110, child: Center(child: Text("Juros")))),
                                    DataColumn(label: SizedBox(width: 110, child: Center(child: Text("Total")))),
                                    DataColumn(label: SizedBox(width: 120, child: Center(child: Text("Parcelas")))),
                                    DataColumn(label: SizedBox(width: 110, child: Center(child: Text("Próx. venc.")))),
                                    DataColumn(label: SizedBox(width: 160, child: Center(child: Text("Situação")))),
                                  ],
                                  rows: emprestimos.map((emp) {
                                    return DataRow(
                                      onSelectChanged: (_) {
                                        emp['cliente'] = cliente['nome'];
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ParcelasPage(emprestimo: emp),
                                          ),
                                        ).then((_) {
                                          setState(() {});
                                        });
                                      },
                                      cells: [
                                        DataCell(SizedBox(width: 160, child: Center(child: Text(cliente['nome'], style: const TextStyle(fontSize: 13))))),
                                        DataCell(SizedBox(width: 100, child: Center(child: Text("${emp['numero'] ?? ''}", style: const TextStyle(fontSize: 13))))),
                                        DataCell(SizedBox(width: 100, child: Center(child: Text(emp['data_inicio'] ?? '', style: const TextStyle(fontSize: 13))))),
                                        DataCell(FutureBuilder<Map<String, String>>(
                                          future: _calcularDatas(emp['id']),
                                          builder: (context, snap) {
                                            if (!snap.hasData) return const Text("-");
                                            return Center(child: Text(snap.data!['ultima'] ?? "-", style: const TextStyle(fontSize: 13)));
                                          },
                                        )),
                                        DataCell(SizedBox(width: 110, child: Center(child: Text(fmtMoeda(_asDouble(emp['valor'])), style: const TextStyle(fontSize: 13))))),
                                        DataCell(SizedBox(width: 110, child: Center(child: Text(fmtMoeda(_asDouble(emp['juros'])), style: const TextStyle(fontSize: 13))))),
                                        DataCell(SizedBox(width: 110, child: Center(child: Text(fmtMoeda(_asDouble(emp['valor']) + _asDouble(emp['juros'])), style: const TextStyle(fontSize: 13))))),
                                        DataCell(SizedBox(
                                          width: 120,
                                          child: Center(
                                            child: Text(
                                              "${emp['parcelas']} x ${fmtMoeda(_asDouble(emp['prestacao']))}",
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        )),
                                        DataCell(FutureBuilder<Map<String, String>>(
                                          future: _calcularDatas(emp['id']),
                                          builder: (context, snap) {
                                            if (!snap.hasData) return const Text("-");
                                            final txt = snap.data!['proxima'] ?? "-";
                                            DateTime? data;
                                            if (txt != "-" && txt.isNotEmpty) {
                                              data = DateFormat("dd/MM/yyyy").tryParse(txt);
                                            }
                                            final vencida = data != null && data.isBefore(DateTime.now());
                                            final temAcordo = snap.data!['acordo'] == "sim";

                                            return Center(
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    txt,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: temAcordo
                                                          ? Colors.orange
                                                          : (vencida ? Colors.red : Colors.black),
                                                      fontWeight: temAcordo || vencida ? FontWeight.bold : FontWeight.normal,
                                                    ),
                                                  ),
                                                  if (temAcordo)
                                                    const Padding(
                                                      padding: EdgeInsets.only(left: 4),
                                                      child: Icon(Icons.warning, size: 16, color: Colors.orange),
                                                    ),
                                                ],
                                              ),
                                            );
                                          },
                                        )),
                                        DataCell(FutureBuilder<Map<String, String>>(
                                          future: _calcularDatas(emp['id']),
                                          builder: (context, snap) {
                                            if (!snap.hasData) return const Text("-");
                                            return Center(child: Text(snap.data!['situacao'] ?? "-", style: const TextStyle(fontSize: 13)));
                                          },
                                        )),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),

                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: FloatingActionButton.extended(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EmprestimoForm(
                                    idCliente: cliente['id_cliente'], // ✅ removido idUsuario
                                    onSaved: () {
                                      setState(() {});
                                    },
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text("Novo Empréstimo"),
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            GarantiasPage(cliente: cliente),
            ArquivadosPage(cliente: cliente),
          ],
        ),
      ),
    );
  }

  double _asDouble(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString()) ?? 0.0;
  }
}
