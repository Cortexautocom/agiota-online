import 'package:flutter/material.dart';
import 'parcelas_service.dart';
import 'parcelas_table.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParcelasPage extends StatefulWidget {
  final Map<String, dynamic> emprestimo;
  final VoidCallback onSaved;

  const ParcelasPage({
    super.key,
    required this.emprestimo,
    required this.onSaved,
  });

  @override
  State<ParcelasPage> createState() => ParcelasPageState();
}

class ParcelasPageState extends State<ParcelasPage> {
  late Future<List<Map<String, dynamic>>> _parcelasFuture;
  final ParcelasService service = ParcelasService();
  final GlobalKey<ParcelasTableState> _tableKey = GlobalKey();

  double aporteTotal = 0.0;
  double capitalPago = 0.0;
  double taxaJuros = 0.0;

  @override
  void initState() {
    super.initState();
    _parcelasFuture = service.buscarParcelas(
      widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'],
    );
    _carregarTaxaDoBanco();
  }

  Future<void> _carregarTaxaDoBanco() async {
    try {
      final response = await Supabase.instance.client
          .from('emprestimos')
          .select('taxa')
          .eq('id', widget.emprestimo['id'])
          .single();

      setState(() {
        taxaJuros = (response['taxa'] as num?)?.toDouble() ?? 0.0;
      });
    } catch (e) {
      print("Erro ao carregar taxa do banco: $e");
      taxaJuros = 0.0;
    }
  }

  Future<void> atualizarParcelas() async {
    setState(() {
      _parcelasFuture = service.buscarParcelas(
        widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'],
      );
    });
  }

  void _adicionarNovaParcela() {
    final tabelaState = _tableKey.currentState;
    if (tabelaState != null) {
      tabelaState.adicionarNovaParcela();
    }
  }

  void _calcularTotais(List<Map<String, dynamic>> parcelas) {
    aporteTotal = widget.emprestimo['valor'] ?? 0.0;
    capitalPago = 0.0;

    for (final p in parcelas) {
      capitalPago += (p['pg_principal'] as num?)?.toDouble() ?? 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final numero = widget.emprestimo["numero"] ?? "";
    final cliente = widget.emprestimo["cliente"] ?? "Cliente";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Voltar para o financeiro',
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text(
                    "Cuidado!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  content: const Text(
                    "Deseja sair sem salvar?",
                    textAlign: TextAlign.center,
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.pop(context, {'atualizar': true, 'cliente': cliente});
                      },
                      icon: const Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 18),
                      label: const Text("Sim, sair sem salvar.",
                          style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Cancelar",
                          style: TextStyle(color: Colors.black87)),
                    ),
                  ],
                );
              },
            );
          },
        ),
        title: Text(
          "Empréstimo Nº $numero - $cliente - Parcelamento",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.grey[100],
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _parcelasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Erro: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red)),
                  );
                }

                final parcelasList = snapshot.data ?? [];
                _calcularTotais(parcelasList);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔹 LADO ESQUERDO - CARD PADRONIZADO + BOTÕES
                    Container(
                      width: 260,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🔹 CARD DE INFORMAÇÕES
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
                                  "Empréstimo Nº $numero",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Cliente: $cliente",
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Divider(height: 10, color: Colors.green),
                                const SizedBox(height: 8),
                                Text(
                                  "Taxa de Juros: ${taxaJuros.toStringAsFixed(2)}% a.m.",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Aporte total: ${service.fmtMoeda2(aporteTotal)}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Capital pago neste empréstimo: ${service.fmtMoeda2(capitalPago)}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Capital restando pagar: ${service.fmtMoeda2(aporteTotal - capitalPago)}",
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

                          // 🔹 BOTÕES LOGO ABAIXO DO CARD
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _adicionarNovaParcela,
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              label: const Text('Adicionar Parcela'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color.fromARGB(255, 132, 224, 135),
                                foregroundColor:
                                    const Color.fromARGB(255, 124, 77, 255),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final ok =
                                    await _tableKey.currentState?.salvarParcelas();
                                if (ok == true && mounted) {
                                  await showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      content: const Text(
                                        "Parcelas salvas com sucesso",
                                        textAlign: TextAlign.center,
                                      ),
                                      actionsAlignment: MainAxisAlignment.center,
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("OK"),
                                        ),
                                      ],
                                    ),
                                  );
                                  widget.onSaved();
                                  Navigator.pop(context, true);
                                }
                              },
                              icon: const Icon(Icons.save, size: 18),
                              label: const Text("Salvar"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color.fromARGB(255, 127, 194, 248),
                                foregroundColor:
                                    const Color.fromARGB(255, 105, 94, 255),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 🔹 LADO DIREITO - TABELA DE PARCELAS (ALINHADA À ESQUERDA)
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.only(top: 16, left: 0, right: 16),
                          child: ParcelasTable(
                            key: _tableKey,
                            emprestimo: widget.emprestimo,
                            parcelas: parcelasList,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 🔹 BOTÃO ARQUIVAR FIXADO NO RODAPÉ, À DIREITA
          Positioned(
            bottom: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Arquivar Empréstimo"),
                    content: const Text(
                      "Tem certeza que deseja arquivar este empréstimo?\n\n"
                      "O empréstimo será movido para a aba de arquivados.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancelar"),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Arquivar"),
                      ),
                    ],
                  ),
                );

                if (confirmar == true) {
                  try {
                    await Supabase.instance.client
                        .from('emprestimos')
                        .update({'ativo': 'nao'})
                        .eq('id', widget.emprestimo['id']);

                    if (!mounted) return;

                    await showDialog(
                      context: context,
                      builder: (ctx) => const AlertDialog(
                        content: Text(
                          "Empréstimo arquivado com sucesso!",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );

                    Navigator.pop(context, true);
                  } catch (e) {
                    if (!mounted) return;
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        content: Text("Erro ao arquivar: $e",
                            textAlign: TextAlign.center),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("OK"),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.archive, size: 18),
              label: const Text("Arquivar Empréstimo"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
