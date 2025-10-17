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
    // 🔹 SE RECEBEU forceRefresh, RECARREGA OS DADOS
    if (widget.forceRefresh && !oldWidget.forceRefresh) {
      _buscarEmprestimos();
    }
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

  /// 🔹 CALCULA VALORES ESPECÍFICOS PARA AMORTIZAÇÃO
  /// 🔹 CALCULA VALORES ESPECÍFICOS PARA AMORTIZAÇÃO
  /// 🔹 CALCULA VALORES ESPECÍFICOS PARA AMORTIZAÇÃO
  Future<Map<String, dynamic>> _calcularValoresAmortizacao(String idEmprestimo) async {
    try {
      // 🔹 BUSCA TODOS OS CAMPOS NECESSÁRIOS
      final parcelas = await Supabase.instance.client
          .from('parcelas')
          .select('juros_periodo, residual, data_mov') // 🔹 USA data_mov COMO VENCIMENTO
          .eq('id_emprestimo', idEmprestimo)
          .order('data_mov'); // 🔹 ORDENA POR data_mov

      // Busca o valor do capital do empréstimo
      final emprestimo = await Supabase.instance.client
          .from('emprestimos')
          .select('valor')
          .eq('id', idEmprestimo)
          .single();

      final capital = _asDouble(emprestimo['valor']);
      
      // Calcula juros totais (soma de todos os juros_periodo)
      double jurosTotais = 0.0;
      for (final parcela in parcelas) {
        jurosTotais += _asDouble(parcela['juros_periodo']);
      }

      // Calcula total (capital + juros totais)
      final total = capital + jurosTotais;

      // Calcula valor da parcela (capital/num_parcelas + juros_totais/num_parcelas)
      final numParcelas = parcelas.length;
      final valorParcela = numParcelas > 0 ? (capital / numParcelas) + (jurosTotais / numParcelas) : 0.0;

      // 🔹 ENCONTRA PRÓXIMA DATA (USA data_mov)
      DateTime? proximaData;
      final agora = DateTime.now();
      
      for (final parcela in parcelas) {
        final dataTexto = parcela['data_mov']?.toString() ?? "";
        if (dataTexto.isEmpty) continue;
        
        final data = DateTime.tryParse(dataTexto);
        if (data == null) continue;

        // Considera apenas parcelas com residual > 0 (não pagas)
        final residual = _asDouble(parcela['residual']);
        if (residual > 0.01 && data.isAfter(agora)) {
          if (proximaData == null || data.isBefore(proximaData)) {
            proximaData = data;
          }
        }
      }

      // Verifica situação (Em dia ou Em atraso)
      String situacao = "Em dia";
      for (final parcela in parcelas) {
        final dataTexto = parcela['data_mov']?.toString() ?? "";
        if (dataTexto.isEmpty) continue;
        
        final data = DateTime.tryParse(dataTexto);
        if (data == null) continue;

        final residual = _asDouble(parcela['residual']);
        // Se tem parcela vencida (antes de hoje) com residual > 0, está em atraso
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
      print('Erro ao calcular valores da amortização: $e');
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
    // 🔹 SE FOR AMORTIZAÇÃO, USA BUSCA DIRETA DO BANCO
    if (tipoMov == 'amortizacao') {
      try {
        // 🔹 BUSCA TODAS AS PARCELAS DO EMPRÉSTIMO
        final parcelas = await Supabase.instance.client
            .from('parcelas')
            .select('data_mov, residual')
            .eq('id_emprestimo', idEmprestimo)
            .order('vencimento');

        DateTime? ultimaData;
        DateTime? proximaData;
        final agora = DateTime.now();

        // 🔹 PROCESSAMENTO DAS PARCELAS
        for (final parcela in parcelas) {
          final vencTxt = parcela['data_mov']?.toString() ?? "";
          if (vencTxt.isEmpty) continue;

          final venc = DateTime.tryParse(vencTxt);
          if (venc == null) continue;

          // 🔹 1. ENCONTRA A MAIOR DATA (ÚLTIMO VENCIMENTO)
          if (ultimaData == null || venc.isAfter(ultimaData)) {
            ultimaData = venc;
          }

          // 🔹 2. ENCONTRA A PRIMEIRA DATA MAIOR QUE HOJE (PRÓXIMO VENCIMENTO)
          // No modelo amortização, não usa residual — considera apenas a data
          if (venc.isAfter(agora)) {
            if (proximaData == null || venc.isBefore(proximaData)) {
              proximaData = venc;
            }
          }

        }

        // 🔹 CALCULA SITUAÇÃO (Em dia ou Em atraso)
        String situacao = "Em dia";
        for (final parcela in parcelas) {
          final vencTxt = parcela['data_mov']?.toString() ?? "";
          if (vencTxt.isEmpty) continue;

          final venc = DateTime.tryParse(vencTxt);
          if (venc == null) continue;

          final residual = _asDouble(parcela['residual']);
          
          // Se tem parcela vencida e não paga, está em atraso
          if (residual > 0.01 && venc.isBefore(agora)) {
            situacao = "Em atraso";
            break;
          }
        }

        return {
          "proxima": proximaData == null 
              ? "-" 
              : DateFormat("dd/MM/yyyy").format(proximaData),
          "ultima": ultimaData == null
              ? "-"
              : DateFormat("dd/MM/yyyy").format(ultimaData),
          "situacao_linha1": situacao,
          "situacao_linha2": "${parcelas.length} parcelas",
          "acordo": "nao",
        };
      } catch (e) {
        print('Erro ao calcular datas para amortização: $e');
        return {
          "proxima": "-",
          "ultima": "-",
          "situacao_linha1": "Em dia",
          "situacao_linha2": "Amortização",
          "acordo": "nao",
        };
      }
    }

    // 🔹 COMPORTAMENTO ORIGINAL PARA PARCELAMENTO (MANTIDO IGUAL)
    // 🔹 Para PARCELAMENTO, usa o campo 'vencimento'
    // 🔹 Para AMORTIZAÇÃO, usa 'data_mov'
    final parcelas = await Supabase.instance.client
        .from('parcelas')
        .select(tipoMov == 'amortizacao'
            ? 'data_mov, residual, data_prevista'
            : 'vencimento, residual, data_prevista')
        .eq('id_emprestimo', idEmprestimo);

    DateTime? proxima;
    DateTime? ultima;
    int pagas = 0;
    int abertas = 0;

    for (final p in parcelas) {
      // 🔹 Escolhe o campo de data conforme o tipo
      final vencTxt = (tipoMov == 'amortizacao'
          ? p['data_mov']
          : p['vencimento'])?.toString() ?? "";

      if (vencTxt.isEmpty) continue;

      final venc = DateTime.tryParse(vencTxt);
      if (venc == null) continue;

      final residual = num.tryParse("${p['residual']}") ?? 0;

      // 🔹 considera paga se residual for próximo de 0
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
      final vencTxt = (tipoMov == 'amortizacao'
          ? p['data_mov']
          : p['vencimento'])?.toString() ?? "";
      if (vencTxt.isEmpty) return false;
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
                                      final tipoMov = emp['tipo_mov'] ?? 'parcelamento';
                                      return DataRow(
                                        onSelectChanged: (_) {
                                          emp['cliente'] = cliente['nome'];
                                          emp['id_cliente'] = cliente['id_cliente'];
                                          emp['id_usuario'] = cliente['id_usuario'] ?? '';
                                          
                                          // 🔹 VERIFICA SE É AMORTIZAÇÃO OU PARCELAMENTO
                                          if (tipoMov == 'amortizacao') {
                                            // 🔹 AMORTIZAÇÃO: Vai para AmortizacaoTabela
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => AmortizacaoTabela(emprestimo: emp),
                                              ),
                                            ).then((resultado) {
                                              // 🔹 Caso a tela de Amortização retorne um mapa (com nome do cliente e flag de atualização)
                                              if (resultado is Map && resultado['atualizar'] == true) {
                                                _buscarEmprestimos();

                                                // 🔹 Atualiza o nome do cliente no título do Financeiro
                                                if (resultado['cliente'] != null) {
                                                  setState(() {
                                                    widget.cliente['nome'] = resultado['cliente'];
                                                  });
                                                }
                                              }
                                              // 🔹 Caso a tela antiga só retorne "true" (compatibilidade)
                                              else if (resultado == true) {
                                                _buscarEmprestimos();
                                              }
                                            });
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
                                            future: _calcularDatas(emp['id'], tipoMov),
                                            builder: (context, snap) =>
                                                !snap.hasData
                                                    ? const Text("-")
                                                    : Center(child: Text(snap.data!['ultima'] ?? "-")),
                                          ))),
                                          DataCell(SizedBox(width: 80, child: Center(child: Text(fmtMoeda(_asDouble(emp['valor'])))))),
                                          // 🔹 COLUNA JUROS: Mostra juros calculados para amortização
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
                                          // 🔹 COLUNA TOTAL: Para amortização é capital + juros totais
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
                                          // 🔹 COLUNA PARCELAS: Para amortização mostra cálculo específico
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
                                          // 🔹 COLUNA SITUAÇÃO: Para amortização mostra "Em dia" ou "Em atraso"
                                          DataCell(SizedBox(width: 75, child: FutureBuilder<Map<String, String>>(
                                            future: _calcularDatas(emp['id'], tipoMov),
                                            builder: (context, snap) => !snap.hasData
                                                ? const Text("-")
                                                : Center(
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        if (tipoMov == 'amortizacao')
                                                          Text(
                                                            snap.data!['situacao_linha1'] ?? "Em dia",
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: (snap.data!['situacao_linha1'] == "Em atraso")
                                                                  ? Colors.red
                                                                  : Colors.green,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          )
                                                        else
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
                                    'id_cliente': cliente['id_cliente'],
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