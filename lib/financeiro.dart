import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas_page.dart';
import 'emprestimo_form.dart';
import 'utils.dart';
import 'package:intl/intl.dart';
import 'garantias.dart';
import 'arquivados_page.dart';
import 'tipo_emprestimo_dialog.dart';
import 'amortizacao_tabela.dart';
import 'package:uuid/uuid.dart';


class FinanceiroPage extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const FinanceiroPage({super.key, required this.cliente});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  late Future<List<Map<String, dynamic>>> _emprestimosFuture;

  @override
  void initState() {
    super.initState();
    _buscarEmprestimos();
  }

  /// 🔹 Recarrega a lista de empréstimos (usado pelos callbacks)
  void _buscarEmprestimos() {
    _emprestimosFuture = Supabase.instance.client
        .from('emprestimos')
        .select()
        .eq('id_cliente', widget.cliente['id_cliente'])
        .eq('ativo', 'sim')
        .order('data_inicio');
    setState(() {});
  }

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

      final venc = DateTime.tryParse(vencTxt);
      if (venc == null) continue;

      final residual = num.tryParse("${p['residual']}") ?? 0;

      // 🔹 considera paga se o residual for próximo de 0
      if (residual.abs() < 0.01) {
        pagas++;
      } else {
        abertas++;
        if (proxima == null || venc.isBefore(proxima)) {
          proxima = venc;
        }
      }

      // 🔹 mantém a última data de vencimento
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

      return residual > 0.01 && // tolerância
          venc != null &&
          proxima != null &&
          venc.isAtSameMomentAs(proxima) &&
          dataPrevista.isNotEmpty;
    });

    return {
      "proxima": proxima == null
          ? "-"
          : DateFormat("dd/MM/yyyy").format(proxima),
      "ultima": ultima == null
          ? "-"
          : DateFormat("dd/MM/yyyy").format(ultima),
      "situacao_linha1": "$pagas pagas",
      "situacao_linha2": "$abertas restando",
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
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // 🔹 Aba 1: Empréstimos Ativos
            Container(
              color: const Color(0xFFFAF9F6),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Empréstimos - ${cliente['nome']}",
                    style: const TextStyle(
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
                          future: _emprestimosFuture,
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

                            final emprestimos =
                                (snapshot.data as List?)
                                        ?.map((e) => e as Map<String, dynamic>)
                                        .toList() ??
                                    [];

                            if (emprestimos.isEmpty) {
                              return const Center(
                                child: Text("Nenhum empréstimo encontrado.",
                                    style: TextStyle(color: Colors.black87)),
                              );
                            }

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Container(
                                constraints: BoxConstraints(
                                  minWidth: MediaQuery.of(context).size.width,
                                ),
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
                                      DataColumn(label: SizedBox(width: 20, child: Center(child: Text("Nº")))),
                                      DataColumn(label: SizedBox(width: 75, child: Center(child: Text("Data Início")))),
                                      DataColumn(label: SizedBox(width: 75, child: Center(child: Text("Último venc.")))),
                                      DataColumn(label: SizedBox(width: 80, child: Center(child: Text("Capital")))),
                                      DataColumn(label: SizedBox(width: 80, child: Center(child: Text("Juros")))),
                                      DataColumn(label: SizedBox(width: 80, child: Center(child: Text("Total")))),
                                      DataColumn(label: SizedBox(width: 100, child: Center(child: Text("Parcelas")))),
                                      DataColumn(label: SizedBox(width: 95, child: Center(child: Text("Próx. venc.")))),
                                      DataColumn(label: SizedBox(width: 75, child: Center(child: Text("Situação")))),
                                    ],
                                    rows: emprestimos.map((emp) {
                                      return DataRow(
                                        onSelectChanged: (_) {
                                          emp['cliente'] = cliente['nome'];
                                          
                                          // 🔹 VERIFICA SE É AMORTIZAÇÃO OU PARCELAMENTO
                                          if (emp['tipo_mov'] == 'amortizacao') {
                                            // 🔹 AMORTIZAÇÃO: Vai para AmortizacaoTabela
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => AmortizacaoTabela(emprestimo: emp),
                                              ),
                                            );
                                          } else {
                                            // 🔹 PARCELAMENTO: Vai para ParcelasPage (comportamento normal)
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ParcelasPage(
                                                  emprestimo: emp,
                                                  onSaved: _buscarEmprestimos,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        cells: [
                                          DataCell(SizedBox(width: 20, child: Center(child: Text("${emp['numero'] ?? ''}")))),
                                          DataCell(SizedBox(width: 75, child: Center(child: Text(_formatarData(emp['data_inicio']))))),
                                          DataCell(SizedBox(width: 75, child: FutureBuilder<Map<String, String>>(
                                            future: _calcularDatas(emp['id']),
                                            builder: (context, snap) =>
                                                !snap.hasData
                                                    ? const Text("-")
                                                    : Center(child: Text(snap.data!['ultima'] ?? "-")),
                                          ))),
                                          DataCell(SizedBox(width: 80, child: Center(child: Text(fmtMoeda(_asDouble(emp['valor'])))))),
                                          DataCell(SizedBox(width: 80, child: Center(child: Text(fmtMoeda(_asDouble(emp['juros'])))))),
                                          DataCell(SizedBox(width: 80, child: Center(child: Text(fmtMoeda(_asDouble(emp['valor']) + _asDouble(emp['juros'])))))),
                                          DataCell(SizedBox(width: 100, child: Center(child: Text("${emp['parcelas']} x ${fmtMoeda(_asDouble(emp['prestacao']))}")))),
                                          DataCell(SizedBox(width: 95, child: FutureBuilder<Map<String, String>>(
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
                                                            : (vencida
                                                                ? Colors.red
                                                                : Colors.black),
                                                        fontWeight: temAcordo || vencida
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                      ),
                                                    ),
                                                    if (temAcordo)
                                                      const Padding(
                                                        padding: EdgeInsets.only(left: 4),
                                                        child: Icon(Icons.warning,
                                                            size: 16, color: Colors.orange),
                                                      ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ))),
                                          DataCell(SizedBox(width: 75, child: FutureBuilder<Map<String, String>>(
                                            future: _calcularDatas(emp['id']),
                                            builder: (context, snap) => !snap.hasData
                                                ? const Text("-")
                                                : Center(
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(snap.data!['situacao_linha1'] ?? "-", style: const TextStyle(fontSize: 11)),
                                                        Text(snap.data!['situacao_linha2'] ?? "-", style: const TextStyle(fontSize: 11)),
                                                      ],
                                                    ),
                                                  ),
                                          ))),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: FloatingActionButton.extended(
                            onPressed: () async {
                              final tipo = await showDialog<String>(
                                context: context,
                                builder: (context) => TipoEmprestimoDialog(
                                  idCliente: cliente['id_cliente'],
                                  idUsuario: cliente['id_usuario'] ?? '',
                                  onSaved: _buscarEmprestimos,
                                ),
                              );

                              if (tipo == null) return; // Usuário cancelou

                              if (tipo == 'parcelamento') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EmprestimoForm(
                                      idCliente: cliente['id_cliente'],
                                      idUsuario: cliente['id_usuario'] ?? '',
                                      onSaved: _buscarEmprestimos,
                                    ),
                                  ),
                                );
                              } else if (tipo == 'amortizacao') {
                                // 🔹 PRIMEIRO CRIA O EMPRÉSTIMO NO BANCO
                                final emprestimoId = Uuid().v4();
                                
                                try {
                                  await Supabase.instance.client.from('emprestimos').insert({
                                    'id': emprestimoId,
                                    'id_cliente': cliente['id_cliente'],
                                    'valor': 0.0, // Valor inicial zero (será calculado depois)
                                    'data_inicio': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                                    'parcelas': 0, // Amortização não tem número fixo de parcelas
                                    'juros': 0.0,
                                    'prestacao': 0.0,
                                    'id_usuario': cliente['id_usuario'] ?? '',
                                    'ativo': 'sim',
                                    'tipo_mov': 'amortizacao', // Novo campo para diferenciar
                                  });

                                  // 🔹 AGORA VAI PARA AMORTIZAÇÃO
                                  final emprestimo = {
                                    'id': emprestimoId,
                                    'cliente': cliente['nome'],
                                  };

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AmortizacaoTabela(emprestimo: emprestimo),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erro ao criar empréstimo: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
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

  String _formatarData(String dataISO) {
    if (dataISO.isEmpty) return "-";
    try {
      final data = DateTime.parse(dataISO);
      return DateFormat("dd/MM/yyyy").format(data);
    } catch (e) {
      return dataISO; // Se der erro, retorna o original
    }
  }
}
