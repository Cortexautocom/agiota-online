import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RelatorioParcelasComAcordo extends StatefulWidget {
  final TextEditingController dataInicioCtrl;
  final TextEditingController dataFimCtrl;

  const RelatorioParcelasComAcordo({
    super.key,
    required this.dataInicioCtrl,
    required this.dataFimCtrl,
  });

  @override
  State<RelatorioParcelasComAcordo> createState() =>
      _RelatorioParcelasComAcordoState();
}

class _RelatorioParcelasComAcordoState
    extends State<RelatorioParcelasComAcordo> {
  bool carregando = false;
  List<Map<String, dynamic>> relatorio = [];

  @override
  void initState() {
    super.initState();
    _buscarParcelasComAcordo();
  }

  String formatarData(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return '';
    }
  }

  DateTime? _parseDataFiltro(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final parts = text.split('/');
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _buscarParcelasComAcordo() async {
    setState(() {
      carregando = true;
      relatorio = [];
    });

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('vw_parcelas_detalhes')
          .select('''
            id,
            numero,
            valor,
            juros,
            residual,
            vencimento,
            data_prevista,
            cliente,
            ativo,
            capital_total,
            juros_total,
            qtd_parcelas
          ''')
          .gt('residual', 0)
          .eq('ativo', 'sim')
          .not('data_prevista', 'is', null) // ✅ Apenas parcelas com acordo
          .order('vencimento', ascending: true);

      final dados = response as List;

      final dataInicio = _parseDataFiltro(widget.dataInicioCtrl.text);
      final dataFim = _parseDataFiltro(widget.dataFimCtrl.text);

      final filtradas = dados.where((p) {
        final venc = DateTime.tryParse(p['vencimento'] ?? '');
        if (venc == null) return false;
        if (dataInicio != null && venc.isBefore(dataInicio)) return false;
        if (dataFim != null && venc.isAfter(dataFim)) return false;
        return true;
      }).toList();

      filtradas.sort((a, b) {
        final da = DateTime.tryParse(a['vencimento'] ?? '') ?? DateTime(2100);
        final db = DateTime.tryParse(b['vencimento'] ?? '') ?? DateTime(2100);
        return da.compareTo(db);
      });

      setState(() {
        relatorio = filtradas.map<Map<String, dynamic>>((p) {
          final nomeCliente = p['cliente'] ?? 'Sem cliente';
          final capitalTotal = (p['capital_total'] ?? 0).toDouble();
          final jurosSupabase = (p['juros_total'] ?? 0).toDouble();
          final qtdParcelas = (p['qtd_parcelas'] ?? 1).toDouble();

          final pgPrincipal = capitalTotal / qtdParcelas;
          final pgJuros = jurosSupabase / qtdParcelas;
          final total = pgPrincipal + pgJuros;

          return {
            'cliente': nomeCliente,
            'numero': p['numero'],
            'vencimento': formatarData(p['vencimento']),
            'data_prevista': formatarData(p['data_prevista']),
            'capital': pgPrincipal,
            'juros': pgJuros,
            'total': total,
          };
        }).toList();
      });
    } catch (_) {
      // Silencia erros
    } finally {
      setState(() {
        carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatador = NumberFormat.currency(locale: "pt_BR", symbol: "R\$");

    double totalCapital = relatorio.fold(0, (s, e) => s + e['capital']);
    double totalJuros = relatorio.fold(0, (s, e) => s + e['juros']);
    double totalGeral = relatorio.fold(0, (s, e) => s + e['total']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: carregando ? null : _buscarParcelasComAcordo,
              icon: const Icon(Icons.search),
              label: const Text("Buscar"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          "📄 Parcelas com acordo vigente",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // 🔹 Cabeçalho
        Container(
          color: Colors.grey[300],
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text("Cliente", style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 1, child: Text("Nº", style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("Vencimento", style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("Data prevista", style: TextStyle(fontWeight: FontWeight.bold))), // ✅ nova coluna
              Expanded(flex: 2, child: Text("Capital", style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("Juros", style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),

        // 🔹 Corpo
        Expanded(
          child: carregando
              ? const Center(child: CircularProgressIndicator())
              : relatorio.isEmpty
                  ? const Center(child: Text("Nenhuma parcela com acordo vigente encontrada."))
                  : ListView.builder(
                      itemCount: relatorio.length,
                      itemBuilder: (context, index) {
                        final item = relatorio[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(item['cliente'])),
                              Expanded(flex: 1, child: Text(item['numero'].toString())),
                              Expanded(flex: 2, child: Text(item['vencimento'] ?? '-')),
                              Expanded(flex: 2, child: Text(item['data_prevista'] ?? '-')), // ✅ exibe data prevista
                              Expanded(flex: 2, child: Text(formatador.format(item['capital']))),
                              Expanded(flex: 2, child: Text(formatador.format(item['juros']))),
                              Expanded(flex: 2, child: Text(formatador.format(item['total']))),
                            ],
                          ),
                        );
                      },
                    ),
        ),

        // 🔹 Totais — alinhados
        if (relatorio.isNotEmpty)
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text("Totais:", style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 1, child: SizedBox()),
                const Expanded(flex: 2, child: SizedBox()),
                const Expanded(flex: 2, child: SizedBox()), // Data prevista
                Expanded(flex: 2, child: Text(formatador.format(totalCapital), style: const TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text(formatador.format(totalJuros), style: const TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text(formatador.format(totalGeral), style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
      ],
    );
  }
}
