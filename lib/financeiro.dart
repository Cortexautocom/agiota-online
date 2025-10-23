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
  final bool forceRefresh;

  const FinanceiroPage({
    super.key, 
    required this.cliente,
    this.forceRefresh = false,
  });

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

  @override
  void didUpdateWidget(FinanceiroPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.forceRefresh && !oldWidget.forceRefresh) {
      _buscarEmprestimos();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _buscarEmprestimos() async {
    setState(() {
      _emprestimosFuture = Supabase.instance.client
          .from('emprestimos')
          .select()
          .eq('id_cliente', widget.cliente['id_cliente'])
          .eq('ativo', 'sim')
          .order('data_inicio');
    });
  }

  Future<Map<String, dynamic>> _calcularValoresAmortizacao(String idEmprestimo) async {
    try {
      final parcelas = await Supabase.instance.client
          .from('parcelas')
          .select('juros_periodo, residual, data_mov')
          .eq('id_emprestimo', idEmprestimo)
          .order('data_mov');

      final emprestimo = await Supabase.instance.client
          .from('emprestimos')
          .select('valor')
          .eq('id', idEmprestimo)
          .single();

      final capital = _asDouble(emprestimo['valor']);
      
      double jurosTotais = 0.0;
      for (final parcela in parcelas) {
        jurosTotais += _asDouble(parcela['juros_periodo']);
      }

      final total = capital + jurosTotais;

      final numParcelas = parcelas.length;
      final valorParcela = numParcelas > 0 ? (capital / numParcelas) + (jurosTotais / numParcelas) : 0.0;

      DateTime? proximaData;
      final agora = DateTime.now();
      
      for (final parcela in parcelas) {
        final dataTexto = parcela['data_mov']?.toString() ?? "";
        if (dataTexto.isEmpty) continue;
        
        final data = DateTime.tryParse(dataTexto);
        if (data == null) continue;

        final residual = _asDouble(parcela['residual']);
        if (residual > 0.01 && data.isAfter(agora)) {
          if (proximaData == null || data.isBefore(proximaData)) {
            proximaData = data;
          }
        }
      }

      String situacao = "Em dia";
      for (final parcela in parcelas) {
        final dataTexto = parcela['data_mov']?.toString() ?? "";
        if (dataTexto.isEmpty) continue;
        
        final data = DateTime.tryParse(dataTexto);
        if (data == null) continue;

        final residual = _asDouble(parcela['residual']);
        if (residual > 0.01 && data.isBefore(agora)) {
          situacao = "Em atraso";
          break;
        }
      }

      return {
        'juros': jurosTotais,
        'total': total,
        'valor_parcela': valorParcela,
        'proxima_data': proximaData,
        'situacao': situacao,
        'num_parcelas': numParcelas,
      };
    } catch (e) {
      return {
        'juros': 0.0,
        'total': 0.0,
        'valor_parcela': 0.0,
        'proxima_data': null,
        'situacao': "Em dia",
        'num_parcelas': 0,
      };
    }
  }

  Future<Map<String, String>> _calcularDatas(String idEmprestimo, String tipoMov) async {
    if (tipoMov == 'amortizacao') {
      try {
        final parcelas = await Supabase.instance.client
            .from('parcelas')
            .select('data_mov, pg, aporte')
            .eq('id_emprestimo', idEmprestimo)
            .order('data_mov');

        int pagas = 0;
        int abertas = 0;
        DateTime? ultimaData;
        DateTime? proximaData;
        final agora = DateTime.now();
        bool temAtraso = false;

        for (final parcela in parcelas) {
          final dataTxt = parcela['data_mov']?.toString() ?? "";
          if (dataTxt.isEmpty) continue;

          final data = DateTime.tryParse(dataTxt);
          if (data == null) continue;

          final pg = int.tryParse(parcela['pg']?.toString() ?? '0') ?? 0;
          final aporteValor = double.tryParse(parcela['aporte']?.toString() ?? '0') ?? 0;

          // Ignora linhas de aporte; considera atraso apenas se for parcela real e vencida
          if (aporteValor == 0 && pg == 0 && data.isBefore(agora)) {
            temAtraso = true;
          }

          if (pg == 1) {
            pagas++;
          } else {
            abertas++;
            if (data.isAfter(agora)) {
              if (proximaData == null || data.isBefore(proximaData)) {
                proximaData = data;
              }
            }
          }

          if (ultimaData == null || data.isAfter(ultimaData)) {
            ultimaData = data;
          }
        }

        return {
          "proxima": proximaData == null
              ? "-"
              : DateFormat("dd/MM/yyyy").format(proximaData),
          "ultima": ultimaData == null
              ? "-"
              : DateFormat("dd/MM/yyyy").format(ultimaData),
          "situacao_linha1": "$pagas pagas",
          "situacao_linha2": "$abertas restando",
          "acordo": temAtraso ? "sim" : "nao",
        };
      } catch (e) {
        return {
          "proxima": "-",
          "ultima": "-",
          "situacao_linha1": "0 pagas",
          "situacao_linha2": "0 restando",
          "acordo": "nao",
        };
      }
    }

    // ======== PARCELAMENTO ========
    try {
      final parcelas = await Supabase.instance.client
          .from('parcelas')
          .select('vencimento, residual, data_prevista')
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

        if (residual.abs() < 0.01) {
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
        final venc = DateTime.tryParse(vencTxt);
        final residual = num.tryParse("${p['residual']}") ?? 0;
        final dataPrevista = p['data_prevista']?.toString().trim() ?? "";

        return residual > 0.01 &&
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
    } catch (e) {
      return {
        "proxima": "-",
        "ultima": "-",
        "situacao_linha1": "0 pagas",
        "situacao_linha2": "0 restando",
        "acordo": "nao",
      };
    }
  }



  @override
  Widget build(BuildContext context) {
    final cliente = widget.cliente;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Financeiro - ${cliente['nome'] ?? 'Cliente'}"),
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
                                      final tipoMov = emp['tipo_mov'] ?? 'parcelamento';
                                      return DataRow(
                                        onSelectChanged: (_) async {
                                          emp['cliente'] = cliente['nome'];
                                          emp['id_cliente'] = cliente['id_cliente'];
                                          emp['id_usuario'] = cliente['id_usuario'] ?? '';

                                          if (tipoMov == 'amortizacao') {
                                            final resultado = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => AmortizacaoTabela(
                                                  emprestimo: emp,
                                                  onSaved: _buscarEmprestimos,
                                                ),
                                              ),
                                            );

                                            if (mounted && (resultado == true || (resultado is Map && resultado['atualizar'] == true))) {
                                              setState(() {
                                                _emprestimosFuture = Supabase.instance.client
                                                    .from('emprestimos')
                                                    .select()
                                                    .eq('id_cliente', widget.cliente['id_cliente'])
                                                    .eq('ativo', 'sim')
                                                    .order('data_inicio');
                                              });
                                            }
                                          } else {
                                            final resultado = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ParcelasPage(
                                                  emprestimo: emp,
                                                  onSaved: _buscarEmprestimos,
                                                ),
                                              ),
                                            );

                                            if (mounted && (resultado == true || (resultado is Map && resultado['atualizar'] == true))) {
                                              _buscarEmprestimos();
                                            }
                                          }
                                        },

                                        cells: [
                                          DataCell(SizedBox(width: 20, child: Center(child: Text("${emp['numero'] ?? ''}")))),
                                          DataCell(SizedBox(width: 75, child: Center(child: Text(_formatarData(emp['data_inicio']))))),
                                          DataCell(SizedBox(width: 75, child: FutureBuilder<Map<String, String>>(
                                            future: _calcularDatas(emp['id'], tipoMov),
                                            builder: (context, snap) =>
                                                !snap.hasData
                                                    ? const Text("-")
                                                    : Center(child: Text(snap.data!['ultima'] ?? "-")),
                                          ))),
                                          DataCell(SizedBox(width: 80, child: Center(child: Text(fmtMoeda(_asDouble(emp['valor'])))))),
                                          DataCell(SizedBox(width: 80, child: Center(child: 
                                            tipoMov == 'amortizacao'
                                                ? FutureBuilder<Map<String, dynamic>>(
                                                    future: _calcularValoresAmortizacao(emp['id']),
                                                    builder: (context, snap) {
                                                      if (!snap.hasData) return Text(fmtMoeda(0.0));
                                                      return Text(fmtMoeda(snap.data!['juros'] ?? 0.0));
                                                    },
                                                  )
                                                : Text(fmtMoeda(_asDouble(emp['juros'])))
                                          ))),
                                          DataCell(SizedBox(width: 80, child: Center(child: 
                                            tipoMov == 'amortizacao'
                                                ? FutureBuilder<Map<String, dynamic>>(
                                                    future: _calcularValoresAmortizacao(emp['id']),
                                                    builder: (context, snap) {
                                                      if (!snap.hasData) return Text(fmtMoeda(_asDouble(emp['valor'])));
                                                      final total = snap.data!['total'] ?? _asDouble(emp['valor']);
                                                      return Text(fmtMoeda(total));
                                                    },
                                                  )
                                                : Text(fmtMoeda(_asDouble(emp['valor']) + _asDouble(emp['juros'])))
                                          ))),
                                          DataCell(SizedBox(width: 100, child: Center(child: 
                                            tipoMov == 'amortizacao'
                                                ? FutureBuilder<Map<String, dynamic>>(
                                                    future: _calcularValoresAmortizacao(emp['id']),
                                                    builder: (context, snap) {
                                                      if (!snap.hasData) return const Text("-");
                                                      final numParcelas = snap.data!['num_parcelas'] ?? 0;
                                                      final valorParcela = snap.data!['valor_parcela'] ?? 0.0;
                                                      return Text("$numParcelas x ${fmtMoeda(valorParcela)}");
                                                    },
                                                  )
                                                : Text("${emp['parcelas']} x ${fmtMoeda(_asDouble(emp['prestacao']))}"))
                                          )),
                                          DataCell(SizedBox(width: 95, child: FutureBuilder<Map<String, String>>(
                                            future: _calcularDatas(emp['id'], tipoMov),
                                            builder: (context, snap) {
                                              if (!snap.hasData) return const Text("-");
                                              final txt = snap.data!['proxima'] ?? "-";

                                              bool temAtraso = false;

                                              // 🧩 Lógica para AMORTIZAÇÃO → pg == 0 e data_mov < hoje (já vem como 'acordo' == 'sim')
                                              if (tipoMov == 'amortizacao') {
                                                temAtraso = snap.data!['acordo'] == 'sim';
                                              } 
                                              // 🧩 Lógica para PARCELAMENTO → se a data de vencimento for anterior a hoje
                                              else {
                                                DateTime? data;
                                                if (txt != "-" && txt.isNotEmpty) {
                                                  data = DateFormat("dd/MM/yyyy").tryParse(txt);
                                                }
                                                if (data != null && data.isBefore(DateTime.now())) {
                                                  temAtraso = true;
                                                }
                                              }

                                              return Center(
                                                child: Text(
                                                  txt,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: temAtraso ? Colors.red : Colors.black,
                                                    fontWeight: temAtraso ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                              );
                                            },
                                          ))),
                                          DataCell(SizedBox(
                                            width: 90,
                                            child: FutureBuilder<Map<String, String>>(
                                              future: _calcularDatas(emp['id'], tipoMov),
                                              builder: (context, snap) {
                                                if (!snap.hasData) return const Text("-");

                                                final tipoTexto = (tipoMov == 'amortizacao') ? "Amortização" : "Parcelamento";
                                                final tipoCor = (tipoMov == 'amortizacao') ? Colors.green : Colors.blue;

                                                final linhaPagas = snap.data!['situacao_linha1'] ?? "0 pagas";
                                                final linhaRestantes = snap.data!['situacao_linha2'] ?? "0 restando";

                                                return Center(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        tipoTexto,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: tipoCor,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        linhaPagas,
                                                        style: const TextStyle(fontSize: 11, color: Colors.black),
                                                      ),
                                                      Text(
                                                        linhaRestantes,
                                                        style: const TextStyle(fontSize: 11, color: Colors.black),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          )),
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

                              if (tipo == null) return;

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
                                final emprestimoId = Uuid().v4();

                                try {
                                  await Supabase.instance.client.from('emprestimos').insert({
                                    'id': emprestimoId,
                                    'id_cliente': cliente['id_cliente'],
                                    'valor': 0.0,
                                    'data_inicio': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                                    'parcelas': 0,
                                    'juros': 0.0,
                                    'prestacao': 0.0,
                                    'id_usuario': cliente['id_usuario'] ?? '',
                                    'ativo': 'sim',
                                    'tipo_mov': 'amortizacao',
                                  });

                                  await _buscarEmprestimos();
                                  await Future.delayed(const Duration(milliseconds: 300));

                                  final emprestimo = {
                                    'id': emprestimoId,
                                    'cliente': cliente['nome'],
                                    'id_cliente': cliente['id_cliente'],
                                    'id_usuario': cliente['id_usuario'] ?? '',
                                    'tipo_mov': 'amortizacao',
                                  };

                                  final resultado = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AmortizacaoTabela(
                                        emprestimo: emprestimo,
                                        onSaved: _buscarEmprestimos,
                                      ),
                                    ),
                                  );

                                  if (mounted && (resultado == true || (resultado is Map && resultado['atualizar'] == true))) {
                                    _buscarEmprestimos();
                                  }
                                } catch (e) {
                                  if (!mounted) return;
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
      return dataISO;
    }
  }
}