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

String fmtMoeda2(dynamic valor) {
  if (valor == null) return "";
  final txt = valor.toString().trim();
  if (txt.isEmpty) return "";
  if (txt.startsWith("R\$")) return txt; // já está formatado
  
  final numero = num.tryParse(txt.replaceAll(",", "."));
  if (numero == null) return txt;

  // 🔹 NOVA LÓGICA: Só adiciona ponto se o valor for >= 1000
  if (numero < 1000) {
    // Valores abaixo de 1000: apenas substitui ponto por vírgula
    final partes = numero.toStringAsFixed(2).split('.');
    return "R\$ ${partes[0]},${partes[1]}";
  } else {
    // Valores acima de 1000: usa o formatador normal com separador de milhar
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
    return data; // aqui já não é mais nulo
  } catch (_) {
    return ""; // se der erro, retorna vazio
  }
}


