import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ NECESSÁRIO para TextInputFormatter
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<bool?> abrirAcordoDialog(
    BuildContext context, Map<String, dynamic> parcela) async {
  // 🔹 Valida se pode abrir acordo
  try {
    final vencimentoTxt = parcela["vencimento"]?.toString() ?? "";
    DateTime? vencimento;

    try {
      // ✅ Detecta automaticamente o formato
      if (vencimentoTxt.contains('-')) {
        // formato ISO (2025-10-03)
        vencimento = DateTime.parse(vencimentoTxt);
      } else if (vencimentoTxt.contains('/')) {
        // formato brasileiro (03/10/2025)
        vencimento = DateFormat("dd/MM/yyyy").parseStrict(vencimentoTxt);
      }
    } catch (_) {
      vencimento = null;
    }

    if (vencimento == null) {
      await showDialog(
        context: context,
        builder: (ctx) => const AlertDialog(
          content: Text(
            "Data de vencimento inválida para criar acordo.",
            textAlign: TextAlign.center,
          ),
        ),
      );
      return false;
    }

    final hoje = DateTime.now();
    final limite = hoje.add(const Duration(days: 7));

    if (vencimento.isAfter(limite)) {
      await showDialog(
        context: context,
        builder: (ctx) => const AlertDialog(
          content: Text(
            "Só é possível criar acordo para parcelas que estão vencendo nos próximos 7 dias.",
            textAlign: TextAlign.center,
          ),
        ),
      );
      return false;
    }
  } catch (_) {
    // Se a data não for válida, não abre
    await showDialog(
      context: context,
      builder: (ctx) => const AlertDialog(
        content: Text(
          "Data de vencimento inválida para criar acordo.",
          textAlign: TextAlign.center,
        ),
      ),
    );
    return false;
  }

  final comentarioCtrl = TextEditingController(text: parcela["comentario"] ?? "");
  
  // 🔹 CORREÇÃO: Inicializar com formato de exibição, mas converter para DateTime
  final dataInicial = parcela["data_prevista"] != null 
      ? _parseDateFromBackend(parcela["data_prevista"])
      : null;
  
  final dataCtrl = TextEditingController(
    text: dataInicial != null 
        ? DateFormat("dd/MM/yyyy").format(dataInicial) 
        : ""
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
                    hintText: "dd/mm/aaaa",
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
                    dataCtrl.text = DateFormat("dd/MM/yyyy", "pt_BR").format(picked);
                  }
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Supabase.instance.client
                .from("parcelas")
                .update({"data_prevista": null, "comentario": null})
                .eq("id", parcela["id"]);

            // Atualiza localmente
            parcela["data_prevista"] = null;
            parcela["comentario"] = null;

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
        ElevatedButton(
          onPressed: () async {
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

            DateTime? acordoDate;
            try {
              acordoDate = DateFormat("dd/MM/yyyy").parseStrict(dataCtrl.text);
            } catch (_) {
              acordoDate = null;
            }

            if (acordoDate == null) {
              await showDialog(
                context: context,
                builder: (ctx) => const AlertDialog(
                  content: Text(
                    "Verifique a data inserida.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
              return;
            }

            final hoje = DateTime.now();
            final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);

            // Critério 2: não pode ser retroativa
            if (!acordoDate.isAfter(hojeSemHora)) {
              await showDialog(
                context: context,
                builder: (ctx) => const AlertDialog(
                  content: Text(
                    "Não é possível criar acordo com data retroativa.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
              return;
            }

            // Critério 1: máximo 90 dias
            if (acordoDate.difference(hojeSemHora).inDays > 90) {
              await showDialog(
                context: context,
                builder: (ctx) => const AlertDialog(
                  content: Text(
                    "Verifique a data inserida.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
              return;
            }

            // 🔹 CORREÇÃO CRÍTICA: Converter para formato ISO
            final dataISO = DateFormat("yyyy-MM-dd").format(acordoDate);

            await Supabase.instance.client
                .from("parcelas")
                .update({
                  "data_prevista": dataISO, // ✅ Agora envia "2024-01-15"
                  "comentario": comentarioCtrl.text,
                })
                .eq("id", parcela["id"]);

            // Atualiza localmente (mantém formato de exibição)
            parcela["data_prevista"] = dataCtrl.text;
            parcela["comentario"] = comentarioCtrl.text;

            if (!context.mounted) return;
            Navigator.pop(context, true);

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

// ✅ FUNÇÃO LOCAL para máscara de data
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

// ✅ FUNÇÃO AUXILIAR para converter dados do backend
DateTime? _parseDateFromBackend(dynamic backendDate) {
  if (backendDate == null) return null;
  
  try {
    if (backendDate is String) {
      // Tenta parse como ISO primeiro
      if (backendDate.contains('-')) {
        return DateTime.parse(backendDate);
      }
      // Se não for ISO, tenta o formato brasileiro
      return DateFormat("dd/MM/yyyy").parseStrict(backendDate);
    }
  } catch (_) {
    return null;
  }
  return null;
}