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
      'data': DateFormat('dd/MM/yyyy').format(DateTime.now()),
      'saldo_inicial': ultimoSaldoFinal,
      'aporte': 0.0,
      'pg_capital': 0.0,
      'pg_juros': 0.0,
      'juros_mes': 0.0,
      'saldo_final': ultimoSaldoFinal,
    });

    _controllers.add({
      'data': TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now())),
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
            _buildHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columnSpacing: 20,
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
                      DataColumn(label: SizedBox(width: 100, child: Center(child: Text("Data")))),
                      DataColumn(label: SizedBox(width: 120, child: Center(child: Text("Saldo inicial")))),
                      DataColumn(label: SizedBox(width: 100, child: Center(child: Text("Aporte")))),
                      DataColumn(label: SizedBox(width: 120, child: Center(child: Text("Pag. capital")))),
                      DataColumn(label: SizedBox(width: 110, child: Center(child: Text("Pag. juros")))),
                      DataColumn(label: SizedBox(width: 100, child: Center(child: Text("Juros mês")))),
                      DataColumn(label: SizedBox(width: 120, child: Center(child: Text("Saldo final")))),
                    ],
                    rows: _linhas
                        .asMap()
                        .entries
                        .map(
                          (entry) => DataRow(
                            cells: [
                              _buildReadOnlyCell(entry.value['data'].toString()),
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
      child: Text(
        "Empréstimo nº ${widget.emprestimo['id'] ?? ''}  |  Cliente: ${widget.emprestimo['cliente'] ?? ''}",
        style: _cellStyle.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}