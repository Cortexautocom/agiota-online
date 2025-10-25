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
      // 🔹 1. Buscar dados organizados por tabelas
      final clientes = await supabase
          .from('clientes')
          .select()
          .eq('id_usuario', user.id)
          .order('nome');

      // Vamos montar um mapa auxiliar de clientes (id_cliente → nome)
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

      // 🔹 2. Enriquecer os dados com nomes e formatações simples
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

      // Criar um mapa de empréstimo → cliente (pra usar nas parcelas)
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

      // 🔹 3. Criar planilha Excel com abas
      final excel = Excel.createExcel();

      void adicionarAba(String nome, List<Map<String, dynamic>> dados) {
        if (dados.isEmpty) {
          excel[nome].appendRow(["(sem dados para exibir)"]);
          return;
        }
        final sheet = excel[nome];
        sheet.appendRow(dados.first.keys.toList()); // Cabeçalhos
        for (var item in dados) {
          sheet.appendRow(item.values.map((v) => v ?? '').toList());
        }
      }

      adicionarAba("Clientes", clientes.cast<Map<String, dynamic>>());
      adicionarAba("Empréstimos", emprestimosFormatados);
      adicionarAba("Parcelas", parcelasFormatadas);
      adicionarAba("Garantias", garantiasFormatadas);

      final bytes = excel.encode()!;

      // 🔹 4. Salvar ou baixar arquivo
      final fileName = "backup_agiomestre_${DateTime.now().toIso8601String().split('T').first}.xlsx";

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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: carregando
          ? const CircularProgressIndicator()
          : ElevatedButton.icon(
              onPressed: gerarBackupExcel,
              icon: const Icon(Icons.download),
              label: const Text("Gerar Backup Excel"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
    );
  }
}
