import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// -------------------------
// 🔹 FORMATAÇÃO DE MOEDA
// -------------------------

final _formatter = NumberFormat.currency(locale: "pt_BR", symbol: "R\$");

String fmtMoeda(dynamic valor) {
  if (valor == null) return "";
  final txt = valor.toString().trim();
  if (txt.isEmpty) return "";
  if (txt.startsWith("R\$")) return txt; // já está formatado
  final numero = num.tryParse(txt.replaceAll(",", "."));
  if (numero == null) return txt;
  return _formatter.format(numero);
}

String fmtMoeda2(dynamic valor) {
  if (valor == null) return "";
  final txt = valor.toString().trim();
  if (txt.isEmpty) return "";
  if (txt.startsWith("R\$")) return txt; // já está formatado

  final numero = num.tryParse(txt.replaceAll(",", "."));
  if (numero == null) return txt;

  // 🔹 NOVA LÓGICA: só adiciona ponto se o valor for >= 1000
  if (numero < 1000) {
    final partes = numero.toStringAsFixed(2).split('.');
    return "R\$ ${partes[0]},${partes[1]}";
  } else {
    final _formatter = NumberFormat.currency(locale: "pt_BR", symbol: "R\$");
    return _formatter.format(numero);
  }
}

/// 🔹 Converte texto formatado (R$ 1.234,56) para número double
double parseMoeda(String? txt) {
  if (txt == null || txt.isEmpty) return 0.0;
  final cleaned = txt
      .replaceAll("R\$", "")
      .replaceAll(".", "")
      .replaceAll(",", ".")
      .trim();
  return double.tryParse(cleaned) ?? 0.0;
}

// -------------------------
// 🔹 FORMATAÇÃO DE DATA
// -------------------------

String formatarData(String? data) {
  if (data == null || data.isEmpty) return "";
  try {
    final partes = data.split("-");
    if (partes.length == 3) {
      final ano = partes[0];
      final mes = partes[1];
      final dia = partes[2];
      return "$dia/$mes/$ano";
    }
    return data;
  } catch (_) {
    return "";
  }
}

// -------------------------
// 🔹 LIMPEZA AUTOMÁTICA DE ACORDOS VENCIDOS
// -------------------------

/// Executa automaticamente no login do usuário
Future<void> verificarAcordosVencidosAoLogin(String idUsuario) async {
  try {
    final supabase = Supabase.instance.client;
    final hoje = DateTime.now();
    final hojeISO =
        "${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}";

    // 🔹 Busca acordos vencidos e ainda não pagos
    final acordosVencidos = await supabase
        .from('parcelas')
        .select('id, id_emprestimo')
        .eq('id_usuario', idUsuario)
        .lt('data_prevista', hojeISO)
        .gte('residual', 1.00);

    if (acordosVencidos.isNotEmpty) {
      // 🔹 Remove o acordo das parcelas vencidas (incluindo anteriores)
      await supabase
          .from('parcelas')
          .update({
            'data_prevista': null,
            'comentario': null,
            'juros_acordo': null,
          })
          .eq('id_usuario', idUsuario)
          .lte('vencimento', hojeISO);

      print("⚠️ Acordos vencidos removidos automaticamente no login (${acordosVencidos.length}).");
    }
  } catch (e) {
    print("❌ Erro ao remover acordos vencidos: $e");
  }
}
