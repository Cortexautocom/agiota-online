import 'package:flutter/material.dart';
import 'parcelas_service.dart';
import 'parcelas_table.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParcelasPage extends StatefulWidget {
  final Map<String, dynamic> emprestimo;

  const ParcelasPage({super.key, required this.emprestimo});

  @override
  State<ParcelasPage> createState() => _ParcelasPageState();
}

class _ParcelasPageState extends State<ParcelasPage> {
  late Future<List<Map<String, dynamic>>> _parcelasFuture;
  final ParcelasService service = ParcelasService();

  // chave para acessar métodos do ParcelasTable
  final GlobalKey<ParcelasTableState> _tableKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _parcelasFuture = service.buscarParcelas(
      widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cliente = widget.emprestimo["cliente"] ?? "";
    final numero = widget.emprestimo["numero"] ?? "";
    final dataInicio = widget.emprestimo["data_inicio"] ?? "";

    // 🔹 usa parseMoeda e fmtMoeda para garantir "R$ 0,00" se for zero ou vazio
    final valor = service.parseMoeda("${widget.emprestimo["valor"] ?? "0"}");
    final juros = service.parseMoeda("${widget.emprestimo["juros"] ?? "0"}");
    final prestacao = service.parseMoeda("${widget.emprestimo["prestacao"] ?? "0"}");
    final parcelas = widget.emprestimo["parcelas"]?.toString() ?? "0";

    return Scaffold(
      appBar: AppBar(
        title: Text("Parcelas - $cliente"),
      ),
      body: Container(
        color: const Color(0xFFFAF9F6),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Resumo
            Text(
              "Nº $numero  |  Data do empréstimo: $dataInicio\n"
              "Capital: ${service.fmtMoeda(valor)} | "
              "Juros: ${service.fmtMoeda(juros)} | "
              "Montante: ${service.fmtMoeda(valor + juros)} | "
              "$parcelas parcelas de ${service.fmtMoeda(prestacao)}",
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 12),

            // 🔹 Lista de parcelas
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _parcelasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Erro: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final parcelas = snapshot.data ?? [];
                  if (parcelas.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nenhuma parcela encontrada.",
                        style: TextStyle(color: Colors.black87),
                      ),
                    );
                  }

                  return ParcelasTable(
                    key: _tableKey, // 👈 chave para chamar salvar
                    emprestimo: widget.emprestimo,
                    parcelas: parcelas,
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // 🔹 Botões inferior direito
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Botão Arquivar
                // Botão Arquivar
                ElevatedButton.icon(
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
                          builder: (ctx) => AlertDialog(
                            content: const Text(
                              "Empréstimo arquivado com sucesso!",
                              textAlign: TextAlign.center,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx); // fecha o diálogo
                                  Navigator.pop(context, true); // volta para financeiro
                                },
                                child: const Text("OK"),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            content: Text(
                              "Erro ao arquivar: $e",
                              textAlign: TextAlign.center,
                            ),
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
                  icon: const Icon(Icons.archive),
                  label: const Text("Arquivar Empréstimo"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                // Botão Salvar
                ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await _tableKey.currentState?.salvarParcelas();

                    if (ok == null) return; // nada retornado

                    if (ok == false && mounted) {
                      // mensagens já são exibidas dentro de salvarParcelas()
                      return;
                    }

                    if (ok == true && mounted) {
                      await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          content: const Text(
                            "Parcelas salvas com sucesso",
                            textAlign: TextAlign.center,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("OK"),
                            ),
                          ],
                        ),
                      );
                      Navigator.pop(context, true); // 👈 retorna true p/ atualizar financeiro
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text("Salvar Parcelas"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
