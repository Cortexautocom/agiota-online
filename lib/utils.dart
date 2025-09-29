import 'package:intl/intl.dart';

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