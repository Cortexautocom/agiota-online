import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RelatorioParcelasEmAberto extends StatefulWidget {
  final TextEditingController dataInicioCtrl;
  final TextEditingController dataFimCtrl;

  const RelatorioParcelasEmAberto({
    super.key,
    required this.dataInicioCtrl,
    required this.dataFimCtrl,
  });

  @override
  State<RelatorioParcelasEmAberto> createState() =>
      _RelatorioParcelasEmAbertoState();
}

class _RelatorioParcelasEmAbertoState
    extends State<RelatorioParcelasEmAberto> {
  bool carregando = false;
  List<Map<String, dynamic>> relatorio = [];

  @override
  void initState() {
    super.initState();
    _buscarParcelasEmAberto();
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

  Future<void> _buscarParcelasEmAberto() async {
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
            cliente,
            ativo,
            capital_total,
            juros_total,
            qtd_parcelas
          ''')
          .gt('residual', 0)
          .eq('ativo', 'sim')
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
          final capital = (p['valor'] ?? 0).toDouble();
          final jurosSupabase = (p['juros_total'] ?? 0).toDouble();
          final qtdParcelas = (p['qtd_parcelas'] ?? 1).toDouble();

          final pgPrincipal = (p['capital_total'] ?? 0) / qtdParcelas;
          final pgJuros = jurosSupabase / qtdParcelas;
          final total = capital + pgJuros;

          return {
            'cliente': nomeCliente,
            'numero': p['numero'],
            'vencimento': formatarData(p['vencimento']),
            'capital': capital,
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
              onPressed: carregando ? null : _buscarParcelasEmAberto,
              icon: const Icon(Icons.search),
              label: const Text("Buscar"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          "📄 Parcelas em aberto",
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
                  ? const Center(child: Text("Nenhuma parcela em aberto encontrada."))
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
                              Expanded(flex: 2, child: Text(formatador.format(item['capital']))),
                              Expanded(flex: 2, child: Text(formatador.format(item['juros']))),
                              Expanded(flex: 2, child: Text(formatador.format(item['total']))),
                            ],
                          ),
                        );
                      },
                    ),
        ),

        // 🔹 Totais — agora alinhados corretamente
        if (relatorio.isNotEmpty)
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    "Totais:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Expanded(flex: 1, child: SizedBox()), // Nº
                const Expanded(flex: 2, child: SizedBox()), // Vencimento
                Expanded(
                  flex: 2,
                  child: Text(
                    formatador.format(totalCapital),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formatador.format(totalJuros),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formatador.format(totalGeral),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
