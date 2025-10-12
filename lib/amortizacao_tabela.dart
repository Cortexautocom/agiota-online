import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'amortizacao_service.dart';
import 'amortizacao_controllers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    // 🔹 PRIMEIRO: Carrega a taxa do banco
    await _carregarTaxaDoBanco();
    
    // 🔹 SEGUNDO: Carrega as parcelas do banco (isso vai criar as linhas automaticamente)
    await _controllers.carregarParcelasDoBanco(widget.emprestimo['id']);
    
    // 🔹 TERCEIRO: Se não há parcelas no banco e é um empréstimo novo, cria linha inicial
    // 🔹 TERCEIRO: Se não há parcelas no banco, busca o valor do empréstimo para criar primeira linha
    if (_controllers.linhas.isEmpty) {
      try {
        // 🔹 BUSCA O VALOR DO EMPRÉSTIMO NO BANCO
        final response = await Supabase.instance.client
            .from('emprestimos')
            .select('valor, data_inicio')
            .eq('id', widget.emprestimo['id'])
            .single();

        final valorEmprestado = (response['valor'] as num?)?.toDouble() ?? 0.0;
        final dataInicio = response['data_inicio']?.toString();
        
        if (valorEmprestado > 0) {
          // 🔹 CRIA PRIMEIRA LINHA COM O VALOR DO EMPRÉSTIMO COMO APORTE
          _controllers.linhas.add({
            'data': dataInicio != null ? _service.toBrDate(dataInicio) ?? DateFormat('dd/MM/yyyy').format(DateTime.now()) : DateFormat('dd/MM/yyyy').format(DateTime.now()),
            'saldo_inicial': 0.0,
            'aporte': valorEmprestado,
            'pg_capital': 0.0,
            'pg_juros': 0.0,
            'juros_mes': 0.0,
            'saldo_final': valorEmprestado,
          });
          _controllers.preencherControllers(); // 🔹 ATUALIZA OS CONTROLLERS
        }
      } catch (e) {
        print('Erro ao buscar valor do empréstimo: $e');
      }
    }
    
    // 🔹 CARREGA OS DADOS FIXOS DO EMPRÉSTIMO UMA ÚNICA VEZ
    try {
      final dadosEmprestimo = await _carregarDadosEmprestimo();
      setState(() {
        // 🔹 CORREÇÃO: Converte int para String corretamente
        final numero = dadosEmprestimo['numero'];
        _numeroEmprestimo = numero?.toString() ?? 'N/A';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Dados salvos com sucesso!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      // 🔹 AGUARDA O SNACKBAR E VOLTA PARA O FINANCEIRO ATUALIZADO
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        // 🔹 VOLTA PASSANDO 'true' PARA INDICAR ATUALIZAÇÃO
        Navigator.pop(context, true);
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
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _salvarNoBanco,
            tooltip: 'Salvar no banco',
          ),
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
                  // 🔹 CARD TAXA DE JUROS
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Taxa de Juros",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controllers.taxaJurosCtrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [_service.percentMaskFormatter()],
                          decoration: const InputDecoration(
                            hintText: '0,00',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            suffixText: '% a.m.',
                          ),
                          onChanged: (text) {
                            setState(() {
                              _controllers.taxaJuros = _service.parsePercent(text);
                              _controllers.recalcularTodosJuros();
                            });
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Taxa: ${_controllers.taxaJuros.toStringAsFixed(2)}%",
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Color.fromARGB(255, 28, 121, 214),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 🔹 CARD INFORMAÇÕES DO EMPRÉSTIMO
                  // 🔹 CARD INFORMAÇÕES DO EMPRÉSTIMO
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
                      headingRowColor: MaterialStateProperty.all(Colors.grey[300]),
                      dataRowMinHeight: 38,
                      dataRowMaxHeight: 42,
                      headingTextStyle: const TextStyle(
                        color: Colors.black, 
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      dataTextStyle: const TextStyle(color: Colors.black87, fontSize: 13),
                      dividerThickness: 0.5,
                      horizontalMargin: 0,
                      columns: const [
                        DataColumn(label: SizedBox(width: 95, child: Center(child: Text("Data")))),
                        DataColumn(label: SizedBox(width: 130, child: Center(child: Text("Saldo Inicial")))),
                        DataColumn(label: SizedBox(width: 105, child: Center(child: Text("Aporte")))),
                        DataColumn(label: SizedBox(width: 115, child: Center(child: Text("Pag. Capital")))),
                        DataColumn(label: SizedBox(width: 105, child: Center(child: Text("Pag. Juros")))),
                        DataColumn(label: SizedBox(width: 95, child: Center(child: Text("Juros (período)")))),
                        DataColumn(label: SizedBox(width: 130, child: Center(child: Text("Saldo Final")))),
                      ],
                      rows: [
                        ..._controllers.linhas
                            .asMap()
                            .entries
                            .map(
                              (entry) => DataRow(
                                cells: [
                                  _buildDateCell(entry.key),
                                  _buildReadOnlyCell(_fmt.format(entry.value['saldo_inicial'] ?? 0.0)),
                                  _buildEditableCell(entry.key, 'aporte', cor: Colors.red),
                                  _buildEditableCell(entry.key, 'pg_capital'),
                                  _buildEditableCell(entry.key, 'pg_juros', cor: const Color.fromARGB(255, 0, 21, 212)),
                                  _buildJurosMesCell(entry.key),
                                  _buildReadOnlyCell(_fmt.format(entry.value['saldo_final'] ?? 0.0)),
                                ],
                              ),
                            )
                            .toList(),
                        DataRow( // 🔹 LINHA DE TOTAIS
                          color: MaterialStateProperty.all(Colors.grey[200]),
                          cells: [
                            DataCell(Center(child: Text("TOTAIS", style: TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(Center(child: Text(""))),
                            DataCell(Center(child: Text(_controllers.fmtMoeda(totalAporte), style: TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(Center(child: Text(_controllers.fmtMoeda(totalPgCapital), style: TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(Center(child: Text(_controllers.fmtMoeda(totalPgJuros), style: TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(Center(child: Text(_controllers.fmtMoeda(totalJurosPeriodo), style: TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(Center(child: Text(_controllers.fmtMoeda(saldoFinal), style: TextStyle(fontWeight: FontWeight.bold)))),
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
              _controllers.calcularJurosAutomatico(index);
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
            onChanged: (text) {
              final valor = _controllers.parseMoeda(text);
              _controllers.linhas[index]['juros_mes'] = valor;
              _controllers.recalcularSaldos();
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
            onChanged: (text) {
              final valor = _controllers.parseMoeda(text);
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