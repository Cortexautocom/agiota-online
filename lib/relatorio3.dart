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
          .order('vencimento', ascending: true);

      final dados = response as List;

      final filtradas = dados.where((p) {
        // 🔹 Apenas parcelas com acordo vigente
        return p['data_prevista'] != null;
      }).toList();

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
            'capital': pgPrincipal,
            'juros': pgJuros,
            'total': total,
          };
        }).toList();
      });
    } catch (_) {
      // silencia erros
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

        // 🔹 Cabeçalho igual aos outros
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

        // 🔹 Corpo idêntico
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
                              Expanded(flex: 2, child: Text(formatador.format(item['capital']))),
                              Expanded(flex: 2, child: Text(formatador.format(item['juros']))),
                              Expanded(flex: 2, child: Text(formatador.format(item['total']))),
                            ],
                          ),
                        );
                      },
                    ),
        ),

        if (relatorio.isNotEmpty)
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text("Totais:", style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 1, child: SizedBox()),
                const Expanded(flex: 2, child: SizedBox()),
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
