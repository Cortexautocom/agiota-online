import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'amortizacao_service.dart';
import 'amortizacao_controllers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'financeiro.dart';

class AmortizacaoTabela extends StatefulWidget {
  final Map<String, dynamic> emprestimo;

  const AmortizacaoTabela({super.key, required this.emprestimo});

  @override
  State<AmortizacaoTabela> createState() => _AmortizacaoTabelaState();
}

class _AmortizacaoTabelaState extends State<AmortizacaoTabela> {
  final AmortizacaoService _service = AmortizacaoService();
  final AmortizacaoControllers _controllers = AmortizacaoControllers();
  final NumberFormat _fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final TextStyle _cellStyle = const TextStyle(fontSize: 13, color: Colors.black87);
  
  String _numeroEmprestimo = 'Carregando...';
  String _nomeCliente = 'Carregando...';


  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    // 🔹 1. Carrega taxa do banco
    await _carregarTaxaDoBanco();

    final supabase = Supabase.instance.client;

    // 🔹 2. Busca parcelas no banco (com o campo ID incluído!)
    final parcelas = await supabase
        .from('parcelas')
        .select('id, data_mov, aporte, pg_principal, pg_juros, juros_periodo')
        .eq('id_emprestimo', widget.emprestimo['id'])
        .order('data_mov', ascending: true);

    // 🔹 3. Se encontrou parcelas, monta as linhas com ID
    if (parcelas.isNotEmpty) {
      _controllers.linhas.clear();

      for (final p in parcelas) {
        final dataBr = _service.toBrDate(p['data_mov']) ??
            DateFormat('dd/MM/yyyy').format(DateTime.now());

        _controllers.linhas.add({
          'id': p['id'], // ✅ agora tem ID!
          'data': dataBr,
          'saldo_inicial': 0.0,
          'aporte': (p['aporte'] as num?)?.toDouble() ?? 0.0,
          'pg_capital': (p['pg_principal'] as num?)?.toDouble() ?? 0.0,
          'pg_juros': (p['pg_juros'] as num?)?.toDouble() ?? 0.0,
          'juros_mes': (p['juros_periodo'] as num?)?.toDouble() ?? 0.0,
          'saldo_final': 0.0,
        });
      }

            _controllers.preencherControllers();
      _controllers.recalcularSaldos();

      // 🔹 NOVO: calcula automaticamente todos os juros ao abrir a tabela
      if (_controllers.linhas.isNotEmpty) {
        _controllers.recalcularTodosJuros();
      }
    } else {
      // 🔹 Se não encontrou parcelas, carrega normalmente via controller
      await _controllers.carregarParcelasDoBanco(widget.emprestimo['id']);

      // 🔹 E também calcula os juros na primeira abertura
      if (_controllers.linhas.isNotEmpty) {
        _controllers.recalcularTodosJuros();
      }
    }

    // 🔹 4. Carrega dados do empréstimo (número e cliente)
    try {
      final dadosEmprestimo = await _carregarDadosEmprestimo();
      setState(() {
        _numeroEmprestimo = dadosEmprestimo['numero']?.toString() ?? 'N/A';
        _nomeCliente = dadosEmprestimo['nome_cliente'] ?? 'Cliente não encontrado';
      });

    } catch (e) {
      print('Erro ao carregar dados do empréstimo: $e');
      setState(() {
        _numeroEmprestimo = 'Erro';
        _nomeCliente = 'Erro ao carregar';
      });
    }
  }


  void _adicionarLinha() {
    if (_controllers.haDataVazia()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preencha todas as datas antes de criar nova linha."),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    _controllers.adicionarLinha();
    setState(() {});
  }

  Future<void> _salvarNoBanco() async {
    final sucesso = await _controllers.salvarParcelasNoBanco(widget.emprestimo['id']);
    
    if (sucesso && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false, // impede fechar clicando fora
        builder: (context) => const AlertDialog(
          title: Text(
            "Sucesso",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Dados salvos com sucesso!",
            textAlign: TextAlign.center,
          ),
        ),
      );

      // Fecha automaticamente após 2 segundos
      Future.delayed(const Duration(seconds: 2), () {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      });
      
      // 🔹 AGUARDA O SNACKBAR E VOLTA PARA O FINANCEIRO ATUALIZADO
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // 🔹 VOLTA PARA O FINANCEIRO FORÇANDO ATUALIZAÇÃO
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => FinanceiroPage(
              cliente: widget.emprestimo,
              forceRefresh: true,
            ),
          ),
          (route) => false,
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro ao salvar dados."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 CALCULAR TOTAIS
    double totalAporte = 0;
    double totalPgCapital = 0;
    double totalPgJuros = 0;
    double totalJurosPeriodo = 0;
    double saldoFinal = _controllers.linhas.isNotEmpty 
        ? (_controllers.linhas.last['saldo_final'] ?? 0.0) 
        : 0.0;

    for (var i = 0; i < _controllers.linhas.length; i++) {
      totalAporte += _controllers.parseMoeda(_controllers.controllers[i]['aporte']!.text);
      totalPgCapital += _controllers.parseMoeda(_controllers.controllers[i]['pg_capital']!.text);
      totalPgJuros += _controllers.parseMoeda(_controllers.controllers[i]['pg_juros']!.text);
      totalJurosPeriodo += _controllers.parseMoeda(_controllers.controllers[i]['juros_mes']!.text);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amortização - Conta Corrente'),
        backgroundColor: Colors.green,
        centerTitle: true,
        actions: [
          /*IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _salvarNoBanco,
            tooltip: 'Salvar no banco',
          ),*/
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 LADO ESQUERDO - PAINEL DE CONTROLE (250px)
            Container(
              width: 250,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 CARD INFORMAÇÕES DO EMPRÉSTIMO (único card à esquerda agora)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Empréstimo Nº ${_numeroEmprestimo}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Cliente: ${_nomeCliente}",
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Divider(height: 10, color: Colors.green),
                        const SizedBox(height: 8),
                        Text(
                          "Taxa de Juros: ${_controllers.taxaJuros.toStringAsFixed(2)}% a.m.",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Aporte total: ${_controllers.fmtMoeda(totalAporte)}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Capital pago neste empréstimo: ${(totalPgCapital > 0) ? _controllers.fmtMoeda(totalPgCapital) : "R\$ 0,00"}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Capital restando pagar: ${_controllers.fmtMoeda(totalAporte - totalPgCapital)}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color.fromARGB(255, 180, 50, 30),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔹 BOTÃO ADICIONAR LINHA
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _adicionarLinha,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nova Linha'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 🔹 BOTÃO SALVAR
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _salvarNoBanco,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Salvar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 LADO DIREITO - TABELA (OCUPA O RESTANTE)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      columnSpacing: 16,
                      headingRowColor:
                          MaterialStateProperty.all(Colors.grey[300]),
                      dataRowMinHeight: 38,
                      dataRowMaxHeight: 42,
                      headingTextStyle: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      dataTextStyle:
                          const TextStyle(color: Colors.black87, fontSize: 13),
                      dividerThickness: 0.5,
                      horizontalMargin: 0,
                      columns: const [
                        DataColumn(
                            label: SizedBox(
                                width: 95,
                                child: Center(child: Text("Data")))),
                        DataColumn(
                            label: SizedBox(
                                width: 130,
                                child: Center(child: Text("Saldo Inicial")))),
                        DataColumn(
                            label: SizedBox(
                                width: 105,
                                child: Center(child: Text("Aporte")))),
                        DataColumn(
                            label: SizedBox(
                                width: 115,
                                child: Center(child: Text("Pag. Capital")))),
                        DataColumn(
                            label: SizedBox(
                                width: 105,
                                child: Center(child: Text("Pag. Juros")))),
                        DataColumn(
                            label: SizedBox(
                                width: 95,
                                child: Center(child: Text("Juros (período)")))),
                        DataColumn(
                            label: SizedBox(
                                width: 130,
                                child: Center(child: Text("Saldo Final")))),
                      ],
                      rows: [
                        ..._controllers.linhas.asMap().entries.map(
                              (entry) => DataRow(
                                cells: [
                                  _buildDateCell(entry.key),
                                  _buildReadOnlyCell(
                                      _fmt.format(entry.value['saldo_inicial'] ?? 0.0)),
                                  _buildEditableCell(entry.key, 'aporte',
                                      cor: Colors.red),
                                  _buildEditableCell(entry.key, 'pg_capital'),
                                  _buildEditableCell(entry.key, 'pg_juros',
                                      cor: const Color.fromARGB(255, 0, 21, 212)),
                                  _buildJurosMesCell(entry.key),
                                  _buildReadOnlyCell(
                                      _fmt.format(entry.value['saldo_final'] ?? 0.0)),
                                ],
                              ),
                            ),
                        DataRow(
                          color: MaterialStateProperty.all(Colors.grey[200]),
                          cells: [
                            DataCell(Center(
                                child: Text("TOTAIS",
                                    style: TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(Center(child: Text(""))),
                            DataCell(Center(
                                child: Text(_controllers.fmtMoeda(totalAporte),
                                    style: TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(Center(
                                child: Text(_controllers.fmtMoeda(totalPgCapital),
                                    style: TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(Center(
                                child: Text(_controllers.fmtMoeda(totalPgJuros),
                                    style: TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(Center(
                                child: Text(_controllers.fmtMoeda(totalJurosPeriodo),
                                    style: TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(Center(
                                child: Text(_controllers.fmtMoeda(saldoFinal),
                                    style: TextStyle(fontWeight: FontWeight.bold)))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 CÉLULA DE DATA EDITÁVEL
  DataCell _buildDateCell(int index) {
    final controller = _controllers.controllers[index]['data']!;
    final isEmpty = controller.text.isEmpty;

    return DataCell(
      Container(
        decoration: BoxDecoration(
          color: isEmpty ? Colors.red[50] : null,
          border: Border(
            right: BorderSide(color: Colors.grey[300]!, width: 0.5),
          ),
        ),
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          style: _cellStyle.copyWith(
            color: isEmpty ? Colors.red[700] : Colors.black87,
          ),
          inputFormatters: [_service.dateMaskFormatter()],
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            hintText: 'dd/mm/aaaa',
          ),
          onChanged: (text) {
            if (text.isNotEmpty) {
              _controllers.linhas[index]['data'] = text;
              _controllers.recalcularSaldos();              
              //_controllers.calcularJurosAutomatico(index);
              _controllers.recalcularTodosJuros();
              setState(() {});
            }
          },
          onTap: () {
            if (controller.text.isNotEmpty) {
              controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              );
            }
          },
        ),
      ),
    );
  }

  // 🔹 CÉLULA ESPECIAL PARA JUROS MÊS (EDITÁVEL + CÁLCULO AUTOMÁTICO)
  DataCell _buildJurosMesCell(int index) {
    final controller = _controllers.controllers[index]['juros_mes']!;

    return DataCell(
      Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey[300]!, width: 0.5),
          ),
        ),
        child: Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              final valor = _controllers.parseMoeda(controller.text);
              controller.text = _controllers.fmtMoeda(valor);
              _controllers.linhas[index]['juros_mes'] = valor;
              _controllers.recalcularSaldos();
              _controllers.recalcularTodosJuros();
              setState(() {});
            }
          },
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            style: _cellStyle.copyWith(color: const Color.fromARGB(255, 28, 121, 214)),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              hintText: '0,00',
            ),
            /*onChanged: (text) {
              final valor = _controllers.parseMoeda(text);
              _controllers.linhas[index]['juros_mes'] = valor;
              _controllers.recalcularSaldos();
              setState(() {});
            },*/
            onTap: () {
              if (controller.text.isNotEmpty) {
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // 🔹 CÉLULA EDITÁVEL COM A MESMA LÓGICA DO PARCELASTABLE
  DataCell _buildEditableCell(int index, String campo, {Color? cor}) {
    final controller = _controllers.controllers[index][campo]!;

    return DataCell(
      Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey[300]!, width: 0.5),
          ),
        ),
        child: Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              final valor = _controllers.parseMoeda(controller.text);
              controller.text = _controllers.fmtMoeda(valor);
              _controllers.linhas[index][campo] = valor;
              _controllers.recalcularSaldos();
              _controllers.recalcularTodosJuros();
              setState(() {});
            }
          },
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            style: _cellStyle.copyWith(color: cor ?? Colors.black87),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              hintText: '0,00',
            ),
            onEditingComplete: () { // Pressionou Enter
              final valor = _controllers.parseMoeda(controller.text);
              controller.text = _controllers.fmtMoeda(valor);
              _controllers.linhas[index][campo] = valor;
              _controllers.recalcularSaldos();
              _controllers.recalcularTodosJuros();
              setState(() {});
            },
            onTap: () {
              if (controller.text.isNotEmpty) {
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // 🔹 CÉLULA SOMENTE LEITURA
  DataCell _buildReadOnlyCell(String texto) {
    return DataCell(
      Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey[300]!, width: 0.5),
          ),
        ),
        child: Center(
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: _cellStyle,
          ),
        ),
      ),
    );
  }

  Future<void> _carregarTaxaDoBanco() async {
    try {
      // 🔹 BUSCA EMPRÉSTIMO NO BANCO PARA PEGAR A TAXA
      final response = await Supabase.instance.client
          .from('emprestimos')
          .select('taxa')
          .eq('id', widget.emprestimo['id'])
          .single();

      final taxa = (response['taxa'] as num?)?.toDouble() ?? 0.0;
      
      // 🔹 PREENCHE O CAMPO DE TAXA
      if (taxa > 0) {
        _controllers.taxaJuros = taxa;
        _controllers.taxaJurosCtrl.text = taxa.toStringAsFixed(2).replaceAll('.', ',');
        
        // 🔹 RECALCULA JUROS SE JÁ HOUVER LINHAS
        if (_controllers.linhas.isNotEmpty) {
          _controllers.recalcularTodosJuros();
        }
      }
    } catch (e) {
      print('Erro ao carregar taxa do banco: $e');
    }
  }

  Future<Map<String, dynamic>> _carregarDadosEmprestimo() async {
    try {
      final response = await Supabase.instance.client
          .from('emprestimos')
          .select('''
            numero,
            clientes (
              nome
            )
          ''')
          .eq('id', widget.emprestimo['id'])
          .single();

      return {
        'numero': response['numero'], // 🔹 MANTÉM COMO int, CONVERTEMOS DEPOIS
        'nome_cliente': response['clientes']?['nome'] ?? 'Cliente não encontrado',
      };
    } catch (e) {
      print('Erro ao carregar dados do empréstimo: $e');
      return {};
    }
  }




}