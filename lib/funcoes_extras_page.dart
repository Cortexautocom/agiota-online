import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class FuncoesExtrasPage extends StatefulWidget {
  const FuncoesExtrasPage({super.key});

  @override
  State<FuncoesExtrasPage> createState() => _FuncoesExtrasPageState();
}

class _FuncoesExtrasPageState extends State<FuncoesExtrasPage> {
  bool carregando = false;
  String telaAtual = 'menu'; // 🔹 controla se está no menu ou na tela de grupos
  List<String> grupos = [];

  // ==========================================================
  // 🔹 GERA BACKUP EXCEL (mesmo código anterior)
  // ==========================================================
  Future<void> gerarBackupExcel() async {
    setState(() => carregando = true);
    final user = Supabase.instance.client.auth.currentUser;
    final supabase = Supabase.instance.client;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usuário não autenticado.")),
      );
      setState(() => carregando = false);
      return;
    }

    try {
      final clientes = await supabase
          .from('clientes')
          .select()
          .eq('id_usuario', user.id)
          .order('nome');

      final Map<String, String> mapaClientes = {
        for (var c in clientes) c['id_cliente']: c['nome'] ?? ''
      };

      final emprestimos = await supabase
          .from('emprestimos')
          .select()
          .eq('id_usuario', user.id)
          .order('data_inicio');

      final parcelas = await supabase
          .from('parcelas')
          .select()
          .eq('id_usuario', user.id)
          .order('vencimento');

      final garantias = await supabase
          .from('garantias')
          .select()
          .eq('id_usuario', user.id)
          .order('numero');

      List<Map<String, dynamic>> emprestimosFormatados = emprestimos.map((e) {
        return {
          "Cliente": mapaClientes[e['id_cliente']] ?? '',
          "Valor": e['valor'],
          "Data início": e['data_inicio'],
          "Data fim": e['data_fim'],
          "Parcelas": e['parcelas'],
          "Taxa (%)": e['taxa'],
          "Juros": e['juros'],
          "Tipo": e['tipo_mov'],
          "Observação": e['observacao'] ?? '',
        };
      }).toList();

      final Map<String, String> mapaEmprestimos = {
        for (var e in emprestimos)
          e['id']: mapaClientes[e['id_cliente']] ?? ''
      };

      List<Map<String, dynamic>> parcelasFormatadas = parcelas.map((p) {
        return {
          "Cliente": mapaEmprestimos[p['id_emprestimo']] ?? '',
          "Empréstimo": p['id_emprestimo'],
          "Parcela": p['numero'],
          "Valor": p['valor'],
          "Vencimento": p['vencimento'],
          "Pago?": p['pg'] == 1 ? "Sim" : "Não",
          "Valor pago": p['valor_pago'],
          "Data pagamento": p['data_pagamento'],
          "Juros atraso": p['juros_atraso'],
          "Comentário": p['comentario'] ?? '',
        };
      }).toList();

      List<Map<String, dynamic>> garantiasFormatadas = garantias.map((g) {
        return {
          "Cliente": mapaClientes[g['id_cliente']] ?? '',
          "Descrição": g['descricao'],
          "Valor": g['valor'],
          "Número": g['numero'],
        };
      }).toList();

      final excel = Excel.createExcel();

      void adicionarAba(String nome, List<Map<String, dynamic>> dados) {
        if (dados.isEmpty) {
          excel[nome].appendRow(["(sem dados para exibir)"]);
          return;
        }
        final sheet = excel[nome];
        sheet.appendRow(dados.first.keys.toList());
        for (var item in dados) {
          sheet.appendRow(item.values.map((v) => v ?? '').toList());
        }
      }

      adicionarAba("Clientes", clientes.cast<Map<String, dynamic>>());
      adicionarAba("Empréstimos", emprestimosFormatados);
      adicionarAba("Parcelas", parcelasFormatadas);
      adicionarAba("Garantias", garantiasFormatadas);

      final bytes = excel.encode()!;
      final fileName =
          "backup_agiomestre_${DateTime.now().toIso8601String().split('T').first}.xlsx";

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final filePath = "${dir.path}/$fileName";
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Backup salvo em: $filePath")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao gerar backup: $e")),
      );
    }

    setState(() => carregando = false);
  }

  // ==========================================================
  // 🔹 FUNÇÕES PARA EDITAR GRUPOS
  // ==========================================================
  Future<void> _buscarGrupos() async {
    setState(() => carregando = true);
    try {
      final response = await Supabase.instance.client
          .from('clientes')
          .select('grupo')
          .not('grupo', 'is', null)
          .neq('grupo', '')
          .order('grupo', ascending: true);

      final lista = (response as List)
          .map((e) => e['grupo'].toString())
          .toSet()
          .toList();

      setState(() {
        grupos = lista;
        telaAtual = 'grupos'; // muda a tela para a lista de grupos
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao carregar grupos: $e")),
      );
    }
    setState(() => carregando = false);
  }

  Future<void> _editarGrupo(String grupoAntigo) async {
    final controller = TextEditingController(text: grupoAntigo);

    final novoGrupo = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Editar nome do grupo"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: "Novo nome"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Aplicar"),
            ),
          ],
        );
      },
    );

    if (novoGrupo == null || novoGrupo.isEmpty || novoGrupo == grupoAntigo) return;

    try {
      await Supabase.instance.client
          .from('clientes')
          .update({'grupo': novoGrupo})
          .eq('grupo', grupoAntigo);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Grupo '$grupoAntigo' renomeado para '$novoGrupo'.")),
      );

      // Atualiza lista
      await _buscarGrupos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao renomear grupo: $e")),
      );
    }
  }

  // ==========================================================
  // 🔹 CONSTRUÇÃO DA INTERFACE
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    // 🔹 Tela principal (menu com opções)
    if (telaAtual == 'menu') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: gerarBackupExcel,
              icon: const Icon(Icons.download),
              label: const Text("Gerar Backup Excel"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _buscarGrupos,
              icon: const Icon(Icons.group),
              label: const Text("Editar Grupo de Clientes"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    // 🔹 Tela de listagem dos grupos
    if (telaAtual == 'grupos') {
      return Column(
        children: [
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Editar Grupo de Clientes",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => telaAtual = 'menu'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Voltar"),
                ),
              ],
            ),
          ),
          Expanded(
            child: grupos.isEmpty
                ? const Center(
                    child: Text(
                      "Nenhum grupo encontrado.",
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    itemCount: grupos.length,
                    itemBuilder: (context, index) {
                      final grupo = grupos[index];
                      return ListTile(
                        title: Text(grupo),
                        trailing: const Icon(Icons.edit, color: Colors.blue),
                        onTap: () => _editarGrupo(grupo),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
