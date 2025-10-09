import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AmortizacaoTabela extends StatefulWidget {
  final Map<String, dynamic> emprestimo;

  const AmortizacaoTabela({super.key, required this.emprestimo});

  @override
  State<AmortizacaoTabela> createState() => _AmortizacaoTabelaState();
}

class _AmortizacaoTabelaState extends State<AmortizacaoTabela> {
  final List<Map<String, dynamic>> _linhas = [];

  final NumberFormat _fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');

  @override
  void initState() {
    super.initState();
    // 🔹 Linha inicial padrão — apenas layout
    _linhas.add({
      'data': DateFormat('dd/MM/yyyy').format(DateTime.now()),
      'saldo_inicial': 0.0,
      'pg_capital': 0.0,
      'pg_juros': 0.0,
      'saldo_final': 0.0,
    });
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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 700),
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.green[100]),
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Data')),
                        DataColumn(label: Text('Saldo inicial')),
                        DataColumn(label: Text('Pag. capital')),
                        DataColumn(label: Text('Pag. juros')),
                        DataColumn(label: Text('Saldo final')),
                      ],
                      rows: _linhas
                          .map(
                            (linha) => DataRow(
                              cells: [
                                DataCell(Text(linha['data'].toString())),
                                DataCell(
                                  Text(_fmt.format(linha['saldo_inicial'])),
                                ),
                                DataCell(
                                  TextField(
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: '0,00',
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                DataCell(
                                  TextField(
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: '0,00',
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                DataCell(
                                  Text(_fmt.format(linha['saldo_final'])),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _linhas.add({
                    'data': DateFormat('dd/MM/yyyy').format(DateTime.now()),
                    'saldo_inicial': 0.0,
                    'pg_capital': 0.0,
                    'pg_juros': 0.0,
                    'saldo_final': 0.0,
                  });
                });
              },
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
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}
