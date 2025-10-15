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
      .select('id, data_mov, aporte, pg_principal, pg_juros, juros_periodo, juros_atraso, pg') // 🆕 adiciona pg
      .eq('id_emprestimo', widget.emprestimo['id'])
      .order('data_mov', ascending: true);

    // 🔹 3. Se encontrou parcelas, monta as linhas com ID
    if (parcelas.isNotEmpty) {
      _controllers.linhas.clear();

      for (final p in parcelas) {
        final dataBr = _service.toBrDate(p['data_mov']) ??
            DateFormat('dd/MM/yyyy').format(DateTime.now());

        _controllers.linhas.add({
          'id': p['id'],
          'data': dataBr,
          'saldo_inicial': 0.0,
          'aporte': (p['aporte'] as num?)?.toDouble() ?? 0.0,
          'pg_capital': (p['pg_principal'] as num?)?.toDouble() ?? 0.0,
          'pg_juros': (p['pg_juros'] as num?)?.toDouble() ?? 0.0,
          'juros_mes': (p['juros_periodo'] as num?)?.toDouble() ?? 0.0,
          'juros_atraso': (p['juros_atraso'] as num?)?.toDouble() ?? 0.0,
          'pg': (p['pg'] as int?) ?? 0,
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
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            //title: const Text("Atenção"), // Título opcional
            content: const Text("Preencha todas as datas antes de criar nova linha."),
            actions: <Widget>[
              TextButton(
                child: const Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop(); // Fecha a janela
                },
              ),
            ],
          );
        },
      );
      return;
    }
    _controllers.adicionarLinha();
    setState(() {});
  }

  Future<void> _salvarNoBanco() async {
    final sucesso = await _controllers.salvarParcelasNoBanco(widget.emprestimo['id']);

    // 🧩 Verifica antes de qualquer ação se a tela ainda está montada
    if (!mounted) return;

    if (sucesso) {
      if (!mounted) return;
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
        if (mounted && Navigator.canPop(context)) { // 🛡️ verifica se a tela ainda existe
          Navigator.of(context).pop();
        }
      });

      // Aguarda o snackbar e volta para o financeiro atualizado
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
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
    } else {
      if (!mounted) return;
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
    double jurosEmAtraso = _calcularJurosEmAtraso();
    double totalJurosAtraso = 0;

    for (var i = 0; i < _controllers.linhas.length; i++) {
      totalAporte += _controllers.parseMoeda(_controllers.controllers[i]['aporte']!.text);
      totalPgCapital += _controllers.parseMoeda(_controllers.controllers[i]['pg_capital']!.text);
      totalPgJuros += _controllers.parseMoeda(_controllers.controllers[i]['pg_juros']!.text);
      totalJurosPeriodo += _controllers.parseMoeda(_controllers.controllers[i]['juros_mes']!.text);
      totalJurosAtraso += _controllers.parseMoeda(_controllers.controllers[i]['juros_atraso']!.text);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Voltar para o financeiro',
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => FinanceiroPage(
                  cliente: widget.emprestimo,
                  forceRefresh: true, // 🔹 garante atualização dos dados
                ),
              ),
            );
          },
        ),
        title: Text(
          "Empréstimo Nº $_numeroEmprestimo - $_nomeCliente - Amortização",
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis, // evita quebrar se o nome for grande
        ),
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
                        const SizedBox(height: 6),
                        Text(
                          "Juros acumulados para o próximo vencimento:",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (jurosEmAtraso > 0)
                              ? _controllers.fmtMoeda(jurosEmAtraso)
                              : "R\$ 0,00",
                          style: TextStyle(
                            fontSize: 13,
                            color: _existeParcelaEmAtraso()
                                ? Colors.redAccent
                                : const Color.fromARGB(255, 28, 121, 214), // 🟢 mesmo verde-azulado dos juros
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _adicionarLinha,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nova Linha'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 132, 224, 135),
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
                        backgroundColor: const Color.fromARGB(255, 127, 194, 248),
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
                              width: 105,
                              child: Center(child: Text("Juros (atraso)")))),
                        DataColumn(
                            label: SizedBox(
                                width: 130,
                                child: Center(child: Text("Saldo Final")))),
                        DataColumn(
                            label: SizedBox(
                              width: 50, // 🔹 largura mínima para o texto e a checkbox
                              child: Center(
                                child: Text(
                                  "Pg.",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                      rows: [
                        ..._controllers.linhas.asMap().entries.map(
                          (entry) {
                            final linha = entry.value;
                            final dataTexto = linha['data'];
                            final pgCapital = linha['pg_capital'] ?? 0.0;
                            final pgJuros = linha['pg_juros'] ?? 0.0;
                            //final desconsiderar = linha['desconsiderar_atraso'] ?? false;

                            Color? rowColor;

                            try {
                              final dataFormatada = DateFormat('dd/MM/yyyy').parse(dataTexto);
                              final hoje = DateTime.now();
                              final isFirstRow = entry.key == 0;

                              final estaAtrasado = !isFirstRow &&
                                  hoje.isAfter(dataFormatada) &&
                                  pgCapital == 0.0 &&
                                  pgJuros == 0.0;

                              final marcadoComoPago = (linha['pg'] ?? 0) == 1; // 🆕 usa o novo campo

                              if (estaAtrasado && !marcadoComoPago) {
                                rowColor = Colors.red[100]; // 🔴 leve vermelho (atrasado)
                              } else if (marcadoComoPago) {
                                rowColor = Colors.green[100]; // 🟢 verde leve (desconsiderado/pago)
                              } else {
                                rowColor = null;
                              }
                            } catch (e) {
                              rowColor = null;
                            }

                            return DataRow(
                              color: MaterialStateProperty.all(rowColor),
                              cells: [
                                _buildDateCell(entry.key),
                                _buildReadOnlyCell(
                                    _fmt.format(linha['saldo_inicial'] ?? 0.0)),
                                _buildEditableCell(entry.key, 'aporte', cor: Colors.red),
                                _buildEditableCell(entry.key, 'pg_capital', cor: Colors.black),
                                _buildEditableCell(entry.key, 'pg_juros', cor: Colors.green),
                                _buildJurosMesCell(entry.key), // azul já aplicado
                                _buildEditableCell(entry.key, 'juros_atraso', cor: Colors.green),
                                _buildReadOnlyCell(
                                    _fmt.format(linha['saldo_final'] ?? 0.0)),
                                DataCell(
                                  Checkbox(
                                    value: (linha['pg'] ?? 0) == 1, // usa o campo 'pg' como referência
                                    onChanged: (val) {
                                      setState(() {
                                        linha['pg'] = (val ?? false) ? 1 : 0; // atualiza apenas na memória
                                      });
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
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
                                child: Text(_controllers.fmtMoeda(totalJurosAtraso), // 🆕 total de juros atraso
                                    style: TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(Center(
                                child: Text(_controllers.fmtMoeda(saldoFinal),
                                    style: TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(Center(child: Text(""))),
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

              // 🆕 Se for Aporte ou Juros (atraso) e o valor for 0 → deixa vazio
              if ((campo == 'aporte' || campo == 'juros_atraso') && valor == 0.0) {
                controller.text = '';
              } else {
                controller.text = _controllers.fmtMoeda(valor);
              }

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
              if ((campo == 'aporte' || campo == 'juros_atraso') && valor == 0.0) {
                controller.text = '';
              } else {
                controller.text = _controllers.fmtMoeda(valor);
              }
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

  
  double _calcularJurosEmAtraso() {
    double total = 0.0;
    int linhasSomadas = 0;
    final hoje = DateTime.now();
    final formatador = DateFormat('dd/MM/yyyy');

    for (int i = 0; i < _controllers.linhas.length; i++) {
      final linha = _controllers.linhas[i];
      final pg = linha['pg'] ?? 0;

      // 🔹 Ignora linhas marcadas como pagas
      if (pg == 1) continue;

      // 🔹 Ignora a primeira linha (aporte inicial)
      if (i == 0) continue;

      final dataTexto = linha['data'];
      if (dataTexto == null || dataTexto.toString().length != 10) continue;

      try {
        final dataLinha = formatador.parse(dataTexto);

        // 🔹 Soma apenas juros das linhas válidas (não aporte)
        total += (linha['juros_mes'] ?? 0.0) + (linha['juros_atraso'] ?? 0.0);
        linhasSomadas++;

        // 🔹 Se a data for maior que hoje → soma esta e para
        if (dataLinha.isAfter(hoje)) {
          break;
        }

      } catch (e) {
        // ignora datas inválidas
      }
    }

    // 🔹 Se não houver nenhuma linha válida além do aporte → retorna 0
    if (linhasSomadas == 0) return 0.0;

    return total;
  }

  bool _existeParcelaEmAtraso() {
    final hoje = DateTime.now();
    final formatador = DateFormat('dd/MM/yyyy');

    for (int i = 1; i < _controllers.linhas.length; i++) { // ignora a 1ª linha (aporte)
      final linha = _controllers.linhas[i];
      final pg = linha['pg'] ?? 0;

      if (pg == 1) continue; // ignora pagas

      final dataTexto = linha['data'];
      if (dataTexto == null || dataTexto.toString().length != 10) continue;

      try {
        final dataLinha = formatador.parse(dataTexto);

        if (dataLinha.isBefore(hoje)) {
          // encontrou uma parcela vencida e não paga
          return true;
        }
      } catch (e) {
        // ignora erros de data
      }
    }

    return false;
  }



}