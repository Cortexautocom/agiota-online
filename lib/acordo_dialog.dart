import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<bool?> abrirAcordoDialog(
    BuildContext context, Map<String, dynamic> parcela) async {
  // 🔹 Controladores
  final comentarioCtrl = TextEditingController(text: parcela["comentario"] ?? "");
  final jurosCtrl = TextEditingController(
      text: parcela["juros_acordo"] != null && parcela["juros_acordo"] != 0
          ? _formatarMoeda(parcela["juros_acordo"].toDouble())
          : "");

  final dataInicial = parcela["data_prevista"] != null
      ? _parseDateFromBackend(parcela["data_prevista"])
      : null;

  final dataCtrl = TextEditingController(
    text: dataInicial != null
        ? DateFormat("dd/MM/yyyy").format(dataInicial)
        : "",
  );

  final resultado = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      titlePadding: const EdgeInsets.only(left: 8, top: 8, right: 8),
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, false),
          ),
          const SizedBox(width: 4),
          const Text("🤝 Fazer acordo"),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: comentarioCtrl,
            maxLength: 100,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Comentário",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: jurosCtrl,
            inputFormatters: [_moedaFormatter()],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Juros pelo acordo",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: dataCtrl,
                  inputFormatters: [_dateMaskFormatter()],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Data prevista",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.blue),
                onPressed: () async {
                  DateTime initialDate;
                  try {
                    initialDate = DateFormat("dd/MM/yyyy").parse(dataCtrl.text);
                  } catch (_) {
                    initialDate = DateTime.now();
                  }

                  final picked = await showDatePicker(
                    context: context,
                    locale: const Locale("pt", "BR"),
                    initialDate: initialDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    dataCtrl.text =
                        DateFormat("dd/MM/yyyy", "pt_BR").format(picked);
                  }
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        // 🔹 Botão Excluir acordo
        TextButton(
          onPressed: () async {
            await Supabase.instance.client
                .from("parcelas")
                .update({
                  "data_prevista": null,
                  "comentario": null,
                  "juros_acordo": null,
                })
                .eq("id", parcela["id"]);

            parcela["data_prevista"] = null;
            parcela["comentario"] = null;
            parcela["juros_acordo"] = null;

            if (!context.mounted) return;
            Navigator.pop(context, true);

            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                content: const Text(
                  "Acordo excluído!",
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
          },
          child: const Text(
            "Excluir acordo",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),

        // 🔹 Botão Efetivar acordo
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange, foregroundColor: Colors.white),
          onPressed: () async {
            final jurosAcordo = _parseMoeda(jurosCtrl.text.trim());
            if (jurosAcordo <= 0) {
              await showDialog(
                context: context,
                builder: (ctx) => const AlertDialog(
                  content: Text(
                    "Informe um valor de juros maior que zero antes de efetivar o acordo.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
              return;
            }

            final confirmar = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                content: const Text(
                  "Tem certeza que deseja efetivar o acordo?\n\nEssa ação vai alterar a situação da parcela.",
                  textAlign: TextAlign.center,
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
                        foregroundColor: Colors.white),
                    child: const Text("Sim, efetivar"),
                  ),
                ],
              ),
            );

            if (confirmar != true) return;

            final hoje = DateTime.now();
            final dataISO =
                "${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}";

            // 🔹 1. Copia juros_acordo → juros e zera juros_acordo
            await Supabase.instance.client
                .from("parcelas")
                .update({
                  "juros": jurosAcordo,
                  "juros_acordo": null,
                  "data_pagamento": dataISO,
                })
                .eq("id", parcela["id"]);

            // 🔹 2. Simula o cálculo automático (mesma lógica do botão Calc.)
            final emprestimoId = parcela['id_emprestimo'];
            final emprestimo = await Supabase.instance.client
                .from('emprestimos')
                .select()
                .eq('id', emprestimoId)
                .single();

            final capital = num.tryParse("${emprestimo["valor"]}") ?? 0;
            final jurosSupabase = num.tryParse("${emprestimo["juros"]}") ?? 0;
            final qtdParcelas = num.tryParse("${emprestimo["parcelas"]}") ?? 1;

            final pgPrincipal = capital / qtdParcelas;
            final pgJuros = (jurosSupabase / qtdParcelas) + jurosAcordo;

            await Supabase.instance.client
                .from("parcelas")
                .update({
                  "pg_principal": pgPrincipal,
                  "pg_juros": pgJuros,
                })
                .eq("id", parcela["id"]);

            // 🔹 3. Atualiza o objeto local e fecha o diálogo
            parcela["juros"] = jurosAcordo;
            parcela["juros_acordo"] = null;
            parcela["data_pagamento"] = dataISO;
            parcela["pg_principal"] = pgPrincipal;
            parcela["pg_juros"] = pgJuros;

            if (!context.mounted) return;
            Navigator.pop(context, true); // ✅ força o refresh da tela de parcelas

            Future.delayed(const Duration(milliseconds: 300), () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  content: const Text(
                    "Acordo efetivado com sucesso!",
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
            });
          },
          child: const Text("Efetivar acordo"),
        ),

        // 🔹 Botão Salvar (mantém o original)
        ElevatedButton(
          onPressed: () async {
            final jurosAcordo = _parseMoeda(jurosCtrl.text.trim());
            if (jurosAcordo <= 0) {
              await showDialog(
                context: context,
                builder: (ctx) => const AlertDialog(
                  content: Text(
                    "Informe um valor de juros maior que zero.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
              return;
            }

            if (dataCtrl.text.isEmpty) {
              await showDialog(
                context: context,
                builder: (ctx) => const AlertDialog(
                  content: Text(
                    "Escolha uma data prevista.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
              return;
            }

            final acordoDate =
                DateFormat("dd/MM/yyyy").parseStrict(dataCtrl.text);
            final dataISO = DateFormat("yyyy-MM-dd").format(acordoDate);

            await Supabase.instance.client
                .from("parcelas")
                .update({
                  "data_prevista": dataISO,
                  "comentario": comentarioCtrl.text,
                  "juros_acordo": jurosAcordo,
                })
                .eq("id", parcela["id"]);

            parcela["data_prevista"] = dataCtrl.text;
            parcela["comentario"] = comentarioCtrl.text;
            parcela["juros_acordo"] = jurosAcordo;

            if (!context.mounted) return;
            Navigator.pop(context, true); // 🔹 Atualiza tela ao voltar

            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                content: const Text(
                  "Acordo salvo com sucesso!",
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
          },
          child: const Text("Salvar"),
        ),
      ],
    ),
  );

  return resultado ?? false;
}

// 🔹 Máscara de moeda
TextInputFormatter _moedaFormatter() {
  return TextInputFormatter.withFunction((oldValue, newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.isEmpty) return newValue;
    final value = int.parse(text) / 100;
    final formatted = _formatarMoeda(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  });
}

// 🔹 Formata no padrão R$ 1.234,56
String _formatarMoeda(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final real = parts[0];
  final centavos = parts[1];
  String realFormatado = '';
  for (int i = real.length - 1, j = 0; i >= 0; i--, j++) {
    if (j > 0 && j % 3 == 0) {
      realFormatado = '.$realFormatado';
    }
    realFormatado = real[i] + realFormatado;
  }
  return 'R\$ $realFormatado,$centavos';
}

// 🔹 Converte texto formatado de volta para número
double _parseMoeda(String texto) {
  if (texto.isEmpty) return 0.0;
  final cleaned = texto
      .replaceAll('R\$', '')
      .replaceAll('.', '')
      .replaceAll(',', '.')
      .trim();
  return double.tryParse(cleaned) ?? 0.0;
}

// 🔹 Máscara de data
TextInputFormatter _dateMaskFormatter() {
  return TextInputFormatter.withFunction((oldValue, newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 8) text = text.substring(0, 8);
    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 1 || i == 3) formatted += '/';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  });
}

// 🔹 Converte data do backend
DateTime? _parseDateFromBackend(dynamic backendDate) {
  if (backendDate == null) return null;
  try {
    if (backendDate is String) {
      if (backendDate.contains('-')) {
        return DateTime.parse(backendDate);
      }
      return DateFormat("dd/MM/yyyy").parseStrict(backendDate);
    }
  } catch (_) {
    return null;
  }
  return null;
}
