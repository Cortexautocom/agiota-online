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
  
  // 🔹 VALIDA DATA
  bool _isValidDate(String text) {
    if (text.isEmpty) return true;
    final parts = text.split('/');
    if (parts.length != 3) return false;
    
    try {
      final dia = int.parse(parts[0]);
      final mes = int.parse(parts[1]);
      final ano = int.parse(parts[2]);
      
      if (dia < 1 || dia > 31) return false;
      if (mes < 1 || mes > 12) return false;
      if (ano < 1900 || ano > 2100) return false;
      
      final date = DateTime(ano, mes, dia);
      return date.day == dia && date.month == mes && date.year == ano;
    } catch (e) {
      return false;
    }
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
    final double ultimoSaldoFinal =
        _linhas.isNotEmpty ? _linhas.last['saldo_final'] ?? 0.0 : 0.0;

    _linhas.add({
      'data': '',   //DateFormat('dd/MM/yyyy').format(DateTime.now()),
      'saldo_inicial': ultimoSaldoFinal,
      'aporte': 0.0,
      'pg_capital': 0.0,
      'pg_juros': 0.0,
      'juros_mes': 0.0,
      'saldo_final': ultimoSaldoFinal,
    });

    _controllers.add({
      'data':TextEditingController(),   //TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now())),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔹 HEADER COM MESMA LARGURA DA TABELA
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 880), // 🔹 MESMA LARGURA DA TABELA
              child: _buildHeader(),
            ),
            const SizedBox(height: 8),
            Expanded(
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
                    horizontalMargin: 12,
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
                              _buildDateCell(entry.key), // 🔹 AGORA EDITÁVEL
                              _buildReadOnlyCell(_fmt.format(entry.value['saldo_inicial'] ?? 0.0)),
                              _buildEditableCell(entry.key, 'aporte', cor: Colors.red),
                              _buildEditableCell(entry.key, 'pg_capital'),
                              _buildEditableCell(entry.key, 'pg_juros', cor: const Color(0xFF001F3F)),
                              _buildEditableCell(entry.key, 'juros_mes', cor: const Color(0xFF001F3F)),
                              _buildReadOnlyCell(_fmt.format(entry.value['saldo_final'] ?? 0.0)),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _adicionarLinha,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar linha'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          color: isEmpty ? const Color.fromARGB(255, 250, 218, 222) : null,
          border: Border(
            right: BorderSide(color: Colors.grey[300]!, width: 0.5),
          ),
        ),
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          style: _cellStyle.copyWith(
            color: isEmpty ? Colors.red[700] : Colors.black87, // 🔹 TEXTO VERMELHO SE VAZIO
          ),
          inputFormatters: [_dateMaskFormatter()],
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            hintText: 'dd/mm/aaaa',
          ),
          onChanged: (text) {
            // Validação em tempo real - opcional
            if (text.length == 10 && !_isValidDate(text)) {
              // Pode adicionar feedback visual se quiser
            }
          },
          onTap: () {
            // Seleciona todo o texto ao clicar
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
              // Formata o valor quando o campo perde o foco
              final valor = _parseMoeda(controller.text);
              controller.text = _fmtMoeda(valor);
              
              // Atualiza o valor na linha e recalcula
              _linhas[index][campo] = valor;
              _recalcularSaldos();
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
              // Atualiza em tempo real para cálculo
              final valor = _parseMoeda(text);
              _linhas[index][campo] = valor;
              _recalcularSaldos();
            },
            onTap: () {
              // Seleciona todo o texto ao clicar
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Center(
        child: Text(
          "Empréstimo nº ${widget.emprestimo['id'] ?? ''}  |  Cliente: ${widget.emprestimo['cliente'] ?? ''}",
          style: _cellStyle.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}