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
