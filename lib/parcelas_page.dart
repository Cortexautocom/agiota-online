import 'package:flutter/material.dart';
import 'parcelas_service.dart';
import 'parcelas_table.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils.dart';

class ParcelasPage extends StatefulWidget {
  final Map<String, dynamic> emprestimo;
  final VoidCallback onSaved; // ✅ callback para atualizar o Financeiro

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

  @override
  void initState() {
    super.initState();
    _parcelasFuture = service.buscarParcelas(
      widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'],
    );
  }

  Future<void> atualizarParcelas() async {
    setState(() {
      _parcelasFuture = service.buscarParcelas(
        widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'],
      );
    });
  }

  // 🔹 MÉTODO CORRETO: Adicionar nova parcela
  void _adicionarNovaParcela() {
    final tabelaState = _tableKey.currentState;
    if (tabelaState != null) {
      tabelaState.adicionarNovaParcela();
    }
  }

  @override
  Widget build(BuildContext context) {
    final numero = widget.emprestimo["numero"] ?? "";
    final cliente = widget.emprestimo["cliente"] ?? "Cliente";
    final dataInicio = formatarData(widget.emprestimo["data_inicio"]);
    final valor = widget.emprestimo['valor'] ?? 0.0;
    final juros = widget.emprestimo['juros'] ?? 0.0;
    final montante = valor + juros;
    final parcela = widget.emprestimo['prestacao'] ?? 0.0;

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
                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                      label: const Text("Sim, sair sem salvar.", style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Cancelar", style: TextStyle(color: Colors.black87)),
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
      body: Container(
        color: Colors.grey[100],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 LADO ESQUERDO - CARD INFORMAÇÕES
            Container(
              width: 260,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // 🔹 fixa o botão no rodapé
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 CONTEÚDO SUPERIOR
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 CARD DE DADOS
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
                            Text("Empréstimo Nº $numero",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 6),
                            Text("Cliente: $cliente",
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Divider(height: 10, color: Colors.blue),
                            const SizedBox(height: 8),
                            Text("Data do Empréstimo: $dataInicio",
                                style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            const SizedBox(height: 6),
                            Text("Capital: ${service.fmtMoeda2(valor)}",
                                style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            const SizedBox(height: 6),
                            Text("Juros: ${service.fmtMoeda2(juros)}",
                                style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            const SizedBox(height: 6),
                            Text("Montante: ${service.fmtMoeda2(montante)}",
                                style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            const SizedBox(height: 6),
                            Text("Parcela: ${service.fmtMoeda2(parcela)}",
                                style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 🔹 BOTÃO ADICIONAR PARCELA
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _adicionarNovaParcela,
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Adicionar Parcela'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 132, 224, 135),
                            foregroundColor: const Color.fromARGB(255, 124, 77, 255),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 🔹 BOTÃO SALVAR
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final ok = await _tableKey.currentState?.salvarParcelas();
                            if (ok == true && mounted) {
                              await showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  content: const Text(
                                    "Parcelas salvas com sucesso", 
                                    textAlign: TextAlign.center
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
                            backgroundColor: const Color.fromARGB(255, 127, 194, 248),
                            foregroundColor: const Color.fromARGB(255, 105, 94, 255),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 🔹 BOTÃO ARQUIVAR FIXADO NO RODAPÉ
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: double.infinity,
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
                                  content: Text("Empréstimo arquivado com sucesso!",
                                      textAlign: TextAlign.center),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 LADO DIREITO - TABELA DE PARCELAS
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
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

                    return ParcelasTable(
                      key: _tableKey,
                      emprestimo: widget.emprestimo,
                      parcelas: parcelasList,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
