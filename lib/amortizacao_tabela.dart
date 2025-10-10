import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class AmortizacaoTabela extends StatefulWidget {
  final Map<String, dynamic> emprestimo;

  const AmortizacaoTabela({super.key, required this.emprestimo});

  @override
  State<AmortizacaoTabela> createState() => _AmortizacaoTabelaState();
}

class _AmortizacaoTabelaState extends State<AmortizacaoTabela> {
  final List<Map<String, dynamic>> _linhas = [];
  final List<Map<String, TextEditingController>> _controllers = [];
  final NumberFormat _fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final TextStyle _cellStyle =
      const TextStyle(fontSize: 13, color: Colors.black87);
  
  final TextEditingController _taxaJurosCtrl = TextEditingController();
  double _taxaJuros = 0.0;

  @override
  void initState() {
    super.initState();
    _linhas.add({
      'data': DateFormat('dd/MM/yyyy').format(DateTime.now()),
      'saldo_inicial': 0.0,
      'aporte': 0.0,
      'pg_capital': 0.0,
      'pg_juros': 0.0,
      'juros_mes': 0.0,
      'saldo_final': 0.0,
    });
    _preencherControllers();
  }

  void _preencherControllers() {
    _controllers.clear();
    for (final linha in _linhas) {
      _controllers.add({
        'data': TextEditingController(text: linha['data'].toString()),
        'aporte': TextEditingController(text: _fmtMoeda(linha['aporte'])),
        'pg_capital': TextEditingController(text: _fmtMoeda(linha['pg_capital'])),
        'pg_juros': TextEditingController(text: _fmtMoeda(linha['pg_juros'])),
        'juros_mes': TextEditingController(text: _fmtMoeda(linha['juros_mes'])),
      });
    }
  }

  // 🔹 MÉTODOS IDÊNTICOS AO PARCELAS_SERVICE
  String _fmtMoeda(double valor) {
    if (valor == 0.0) return '';
    return _fmt.format(valor);
  }

  double _parseMoeda(String texto) {
    if (texto.isEmpty) return 0.0;
    final cleaned = texto
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  // 🔹 MÉTODO PARA FORMATAÇÃO DE PORCENTAGEM
  TextInputFormatter _percentMaskFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      var text = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');
      
      // Permite apenas uma vírgula
      final commaCount = text.split(',').length - 1;
      if (commaCount > 1) {
        text = text.substring(0, text.length - 1);
      }
      
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  double _parsePercent(String texto) {
    if (texto.isEmpty) return 0.0;
    final cleaned = texto.replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  // 🔹 MÉTODO PARA FORMATAÇÃO DE DATA (MÁSCARA dd/mm/aaaa)
  TextInputFormatter _dateMaskFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (text.length >= 3) {
        text = '${text.substring(0, 2)}/${text.substring(2)}';
      }
      if (text.length >= 6) {
        text = '${text.substring(0, 5)}/${text.substring(5)}';
      }
      if (text.length > 10) {
        text = text.substring(0, 10);
      }
      
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  // 🔹 CALCULA DIFERENÇA DE DIAS ENTRE DATAS
  int _calcularDiferencaDias(String dataAnteriorStr, String dataAtualStr) {
    try {
      final partsAnterior = dataAnteriorStr.split('/');
      final partsAtual = dataAtualStr.split('/');
      
      if (partsAnterior.length != 3 || partsAtual.length != 3) return 0;
      
      final dataAnterior = DateTime(
        int.parse(partsAnterior[2]),
        int.parse(partsAnterior[1]),
        int.parse(partsAnterior[0]),
      );
      
      final dataAtual = DateTime(
        int.parse(partsAtual[2]),
        int.parse(partsAtual[1]),
        int.parse(partsAtual[0]),
      );
      
      return dataAtual.difference(dataAnterior).inDays;
    } catch (e) {
      return 0;
    }
  }

  // 🔹 CALCULA JUROS AUTOMATICAMENTE
  void _calcularJurosAutomatico(int index) {
    if (index == 0) return; // Primeira linha não tem linha anterior
    
    final dataAtual = _controllers[index]['data']!.text;
    final dataAnterior = _controllers[index - 1]['data']!.text;
    
    // Só calcula se ambas as datas estiverem preenchidas (dd/mm/aaaa)
    if (dataAtual.length == 10 && dataAnterior.length == 10) {
      final diferencaDias = _calcularDiferencaDias(dataAnterior, dataAtual);
      
      if (diferencaDias > 0 && _taxaJuros > 0) {
        final saldoAnterior = _linhas[index - 1]['saldo_final'] ?? 0.0;
        final jurosCalculado = saldoAnterior * (_taxaJuros / 100 / 30) * diferencaDias;
        
        // Atualiza o campo de juros apenas se estiver vazio ou se for o cálculo automático
        final jurosAtual = _parseMoeda(_controllers[index]['juros_mes']!.text);
        if (jurosAtual == 0.0) {
          _controllers[index]['juros_mes']!.text = _fmtMoeda(jurosCalculado);
          _linhas[index]['juros_mes'] = jurosCalculado;
          _recalcularSaldos();
        }
      }
    }
  }

  // 🔹 RECALCULA TODOS OS JUROS DA PLANILHA
  void _recalcularTodosJuros() {
    for (int i = 1; i < _linhas.length; i++) {
      final dataAtual = _controllers[i]['data']!.text;
      final dataAnterior = _controllers[i - 1]['data']!.text;
      
      if (dataAtual.length == 10 && dataAnterior.length == 10) {
        final diferencaDias = _calcularDiferencaDias(dataAnterior, dataAtual);
        
        if (diferencaDias > 0 && _taxaJuros > 0) {
          final saldoAnterior = _linhas[i - 1]['saldo_final'] ?? 0.0;
          final jurosCalculado = saldoAnterior * (_taxaJuros / 100 / 30) * diferencaDias;
          
          _controllers[i]['juros_mes']!.text = _fmtMoeda(jurosCalculado);
          _linhas[i]['juros_mes'] = jurosCalculado;
        }
      }
    }
    _recalcularSaldos();
  }

  // 🔹 VERIFICA SE HÁ ALGUMA DATA VAZIA NA TABELA
  bool _haDataVazia() {
    for (final controller in _controllers) {
      if (controller['data']!.text.isEmpty) {
        return true;
      }
    }
    return false;
  }

  void _recalcularSaldos() {
    for (int i = 0; i < _linhas.length; i++) {
      final linha = _linhas[i];
      final controller = _controllers[i];
      
      // Atualiza os valores das linhas com os dados dos controllers
      linha['aporte'] = _parseMoeda(controller['aporte']!.text);
      linha['pg_capital'] = _parseMoeda(controller['pg_capital']!.text);
      linha['pg_juros'] = _parseMoeda(controller['pg_juros']!.text);
      linha['juros_mes'] = _parseMoeda(controller['juros_mes']!.text);
      linha['data'] = controller['data']!.text;

      final double saldoInicial = linha['saldo_inicial'] ?? 0.0;
      final double aporte = linha['aporte'] ?? 0.0;
      final double pgCapital = linha['pg_capital'] ?? 0.0;
      final double pgJuros = linha['pg_juros'] ?? 0.0;
      final double jurosMes = linha['juros_mes'] ?? 0.0;

      linha['saldo_final'] =
          saldoInicial + aporte - pgCapital - pgJuros + jurosMes;

      if (i < _linhas.length - 1) {
        _linhas[i + 1]['saldo_inicial'] = linha['saldo_final'];
      }
    }
    setState(() {});
  }

  void _adicionarLinha() {
    // 🔹 VERIFICA SE HÁ ALGUMA DATA VAZIA
    if (_haDataVazia()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preencha todas as datas antes de criar nova linha."),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final double ultimoSaldoFinal =
        _linhas.isNotEmpty ? _linhas.last['saldo_final'] ?? 0.0 : 0.0;

    _linhas.add({
      'data': '',
      'saldo_inicial': ultimoSaldoFinal,
      'aporte': 0.0,
      'pg_capital': 0.0,
      'pg_juros': 0.0,
      'juros_mes': 0.0,
      'saldo_final': ultimoSaldoFinal,
    });

    _controllers.add({
      'data': TextEditingController(),
      'aporte': TextEditingController(),
      'pg_capital': TextEditingController(),
      'pg_juros': TextEditingController(),
      'juros_mes': TextEditingController(),
    });

    _recalcularSaldos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Amortização - Conta Corrente'),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey[100],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 LADO ESQUERDO - PAINEL DE CONTROLE (200px)
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
                          controller: _taxaJurosCtrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [_percentMaskFormatter()],
                          decoration: const InputDecoration(
                            hintText: '0,00',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            suffixText: '% a.m.',
                          ),
                          onChanged: (text) {
                            setState(() {
                              _taxaJuros = _parsePercent(text);
                              // 🔹 RECALCULA TODOS OS JUROS AUTOMATICAMENTE
                              _recalcularTodosJuros();
                            });
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Taxa: ${_taxaJuros.toStringAsFixed(2)}%",
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
                        const Text(
                          "Empréstimo",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Nº ${widget.emprestimo['id'] ?? ''}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Cliente: ${widget.emprestimo['cliente'] ?? ''}",
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
                        DataColumn(label: SizedBox(width: 95, child: Center(child: Text("Juros Mês")))),
                        DataColumn(label: SizedBox(width: 130, child: Center(child: Text("Saldo Final")))),
                      ],
                      rows: _linhas
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
    final controller = _controllers[index]['data']!;
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
          inputFormatters: [_dateMaskFormatter()],
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            hintText: 'dd/mm/aaaa',
          ),
          onChanged: (text) {
            if (text.isNotEmpty) {
              _linhas[index]['data'] = text;
              _recalcularSaldos();              
              _calcularJurosAutomatico(index);
              _recalcularTodosJuros();
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
    final controller = _controllers[index]['juros_mes']!;

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
              final valor = _parseMoeda(controller.text);
              controller.text = _fmtMoeda(valor);
              _linhas[index]['juros_mes'] = valor;
              _recalcularSaldos();
              _recalcularTodosJuros();
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
              final valor = _parseMoeda(text);
              _linhas[index]['juros_mes'] = valor;
              _recalcularSaldos();

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
    final controller = _controllers[index][campo]!;

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
              final valor = _parseMoeda(controller.text);
              controller.text = _fmtMoeda(valor);
              _linhas[index][campo] = valor;
              _recalcularSaldos();
              _recalcularTodosJuros();
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
              final valor = _parseMoeda(text);
              _linhas[index][campo] = valor;
              _recalcularSaldos();
              _recalcularTodosJuros();
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
}