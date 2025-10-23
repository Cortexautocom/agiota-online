import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'relatorio1.dart'; // 🔹 Parcelas em Aberto
import 'relatorio2.dart'; // 🔹 Parcelas em Atraso
import 'relatorio3.dart'; // 🔹 Parcelas com Acordo Vigente

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  String tipoRelatorio = 'Parcelas em aberto';
  bool filtroParcelamento = false;
  bool filtroAmortizacao = false;
  
  // 🔹 NOTIFICADOR GLOBAL para atualizar todos os relatórios
  final _refreshRelatorios = ValueNotifier<bool>(false);

  // Controladores de data
  final dataInicioCtrl = TextEditingController();
  final dataFimCtrl = TextEditingController();
  final dataMask = MaskTextInputFormatter(mask: '##/##/####');

  // Focus nodes para detectar perda de foco
  late final FocusNode inicioFocusNode;
  late final FocusNode fimFocusNode;

  // Flags que indicam que o usuário "finalizou" a edição do campo
  bool dataInicioTouched = false;
  bool dataFimTouched = false;

  // Estados de validação (mantidos para compatibilidade / debug)
  bool dataInicioInvalida = false;
  bool dataFimInvalida = false;
  bool intervaloInvalido = false;

  @override
  void initState() {
    super.initState();
    inicioFocusNode = FocusNode();
    fimFocusNode = FocusNode();

    // Quando perder o foco marcamos como "tocado" e validamos
    inicioFocusNode.addListener(() {
      if (!inicioFocusNode.hasFocus) {
        dataInicioTouched = true;
        _validarDatas();
      }
    });

    fimFocusNode.addListener(() {
      if (!fimFocusNode.hasFocus) {
        dataFimTouched = true;
        _validarDatas();
      }
    });

    _carregarUltimoRelatorio();
  }

  @override
  void dispose() {
    inicioFocusNode.dispose();
    fimFocusNode.dispose();
    dataInicioCtrl.dispose();
    dataFimCtrl.dispose();
    _refreshRelatorios.dispose(); // 🔹 Importante: dispose do notificador
    super.dispose();
  }

  /// Persistência do último relatório selecionado
  Future<void> _salvarUltimoRelatorio() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ultimoRelatorio', tipoRelatorio);
  }

  Future<void> _carregarUltimoRelatorio() async {
    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getString('ultimoRelatorio');
    if (salvo != null && salvo.isNotEmpty) {
      setState(() => tipoRelatorio = salvo);
    }
  }

  /// 🔹 MÉTODO CENTRALIZADO para executar a busca
  void _executarBusca() {
    // Notifica todos os relatórios para atualizar
    _refreshRelatorios.value = !_refreshRelatorios.value;
    FocusScope.of(context).unfocus();
  }

  /// Limpa os campos de data
  void _limparDatas() {
    setState(() {
      dataInicioCtrl.clear();
      dataFimCtrl.clear();
      dataInicioTouched = false;
      dataFimTouched = false;
      dataInicioInvalida = false;
      dataFimInvalida = false;
      intervaloInvalido = false;
    });
    
    // Remove o foco dos campos
    FocusScope.of(context).unfocus();
  }

  /// Limpa datas quando o relatório é alterado
  void _onRelatorioAlterado(String? novoRelatorio) {
    if (novoRelatorio == null) return;
    
    // Limpa os campos de data antes de trocar o relatório
    _limparDatas();
    
    setState(() => tipoRelatorio = novoRelatorio);
    _salvarUltimoRelatorio();
  }

  /// Converte texto -> DateTime (retorna null se inválido)
  DateTime? _parseData(String? texto) {
    if (texto == null || texto.isEmpty) return null;
    try {
      final partes = texto.split('/');
      if (partes.length != 3) return null;

      final dia = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final ano = int.parse(partes[2]);

      // Checks básicos
      if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;

      final data = DateTime(ano, mes, dia);
      // Garante que não houve "rollover" (ex: 31/04 -> 01/05)
      if (data.month != mes || data.day != dia) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Valida datas (é chamada ao perder foco ou ao escolher data no calendário)
  void _validarDatas() {
    final dataInicio = _parseData(dataInicioCtrl.text);
    final dataFim = _parseData(dataFimCtrl.text);

    setState(() {
      // Só consideramos inválido se o usuário já "tocou" no campo (finalizou edição)
      dataInicioInvalida =
          dataInicioTouched && dataInicioCtrl.text.isNotEmpty && dataInicio == null;
      dataFimInvalida =
          dataFimTouched && dataFimCtrl.text.isNotEmpty && dataFim == null;

      // Só validamos o intervalo se as duas datas forem válidas (não vazias)
      intervaloInvalido = false;
      if (dataInicio != null && dataFim != null) {
        if (dataFim.isBefore(dataInicio)) {
          intervaloInvalido = true;
        }
      }
    });
  }

  /// Abre o calendário e marca como "tocado" o campo correto
  Future<void> _selecionarData(
    BuildContext context,
    TextEditingController controller,
  ) async {
    FocusScope.of(context).unfocus();
    DateTime dataInicial = _parseData(controller.text) ?? DateTime.now();

    // 🔹 SOLUÇÃO DEFINITIVA: Criar um DatePickerDialog customizado
    DateTime? dataSelecionada;

    await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return Dialog(
          child: SizedBox(
            width: 330,
            height: 430,
            child: Column(
              children: [
                // Cabeçalho com título
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Selecione a data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                // Calendário
                Expanded(
                  child: CalendarDatePicker(
                    initialDate: dataInicial,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                    onDateChanged: (DateTime value) {
                      dataSelecionada = value;
                      // 🔹 FECHA IMEDIATAMENTE ao clicar na data
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (dataSelecionada != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(dataSelecionada!);

      if (controller == dataInicioCtrl) {
        dataInicioTouched = true;
      } else if (controller == dataFimCtrl) {
        dataFimTouched = true;
      }
      _validarDatas();
      
      // 🔹 BUSCA AUTOMÁTICA quando seleciona data final
      if (controller == dataFimCtrl) {
        _executarBusca();
      }
    }
  }

  /// Decisão de exibir erro/relatório baseada em estado "tocado" e parsing real
  Widget _buildRelatorio() {
    final inicioParsed = _parseData(dataInicioCtrl.text);
    final fimParsed = _parseData(dataFimCtrl.text);

    final inicioInvalidVisible =
        dataInicioTouched && dataInicioCtrl.text.isNotEmpty && inicioParsed == null;
    final fimInvalidVisible =
        dataFimTouched && dataFimCtrl.text.isNotEmpty && fimParsed == null;
    final intervalInvalidVisible = (inicioParsed != null && fimParsed != null && fimParsed.isBefore(inicioParsed));

    // Se houver qualquer erro visível, mostramos a mensagem de correção
    if (inicioInvalidVisible || fimInvalidVisible || intervalInvalidVisible) {
      return const Center(
        child: Text(
          "⚠️ Corrija as datas antes de gerar o relatório.",
          style: TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }

    // Caso contrário, mostramos o relatório correspondente (campos vazios são permitidos)
    switch (tipoRelatorio) {
      case 'Parcelas em aberto':
        return RelatorioParcelasEmAberto(
          dataInicioCtrl: dataInicioCtrl,
          dataFimCtrl: dataFimCtrl,
          refreshNotifier: _refreshRelatorios,
          filtroParcelamento: filtroParcelamento,
          filtroAmortizacao: filtroAmortizacao,
        );

      case 'Parcelas em atraso':
        return RelatorioParcelasVencidas(
          dataInicioCtrl: dataInicioCtrl,
          dataFimCtrl: dataFimCtrl,
          refreshNotifier: _refreshRelatorios,
          filtroParcelamento: filtroParcelamento,
          filtroAmortizacao: filtroAmortizacao, // 🔹 Passe o notificador
        );
      case 'Parcelas com acordo vigente':
        return RelatorioParcelasComAcordo(
          dataInicioCtrl: dataInicioCtrl,
          dataFimCtrl: dataFimCtrl,
          refreshNotifier: _refreshRelatorios, // 🔹 Passe o notificador
        );      
      default:
        return const Center(child: Text("Selecione um tipo de relatório."));
    }
  }

  InputDecoration _decoracaoCampo({
    required String label,
    required bool invalido,
    required VoidCallback onCalendario,
  }) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (invalido) const Icon(Icons.error_outline, color: Colors.red),
          IconButton(
            icon: Icon(
              Icons.calendar_today,
              color: invalido ? Colors.red : const Color.fromARGB(255, 71, 63, 63),
            ),
            onPressed: onCalendario,
          ),
        ],
      ),
      filled: invalido,
      fillColor: invalido ? Colors.red.withOpacity(0.08) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    // recalcula parsings para decidir a cor/estado dos campos
    final inicioParsed = _parseData(dataInicioCtrl.text);
    final fimParsed = _parseData(dataFimCtrl.text);

    final inicioInvalidVisible =
        dataInicioTouched && dataInicioCtrl.text.isNotEmpty && inicioParsed == null;
    final fimInvalidVisible =
        dataFimTouched && dataFimCtrl.text.isNotEmpty && fimParsed == null;
    final intervalInvalidVisible =
        (inicioParsed != null && fimParsed != null && fimParsed.isBefore(inicioParsed));

    final corIntervalo = intervalInvalidVisible ? Colors.red.withOpacity(0.08) : null;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha superior — tipo + datas
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: tipoRelatorio,
                  decoration: const InputDecoration(
                    labelText: "Tipo de relatório",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: "Parcelas em aberto",
                        child: Text("Parcelas em aberto")),
                    DropdownMenuItem(
                        value: "Parcelas em atraso",
                        child: Text("Parcelas em atraso")),
                    DropdownMenuItem(
                        value: "Parcelas com acordo vigente",
                        child: Text("Parcelas com acordo vigente")),                    
                  ],
                  onChanged: _onRelatorioAlterado,
                ),
              ),
              const SizedBox(width: 16),

              // Data inicial
              Expanded(
                child: TextField(
                  controller: dataInicioCtrl,
                  focusNode: inicioFocusNode,
                  decoration: _decoracaoCampo(
                    label: "Data inicial",
                    invalido: inicioInvalidVisible || intervalInvalidVisible,
                    onCalendario: () => _selecionarData(context, dataInicioCtrl),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [dataMask],
                  onEditingComplete: () {
                    // usuário finalizou edição via teclado
                    dataInicioTouched = true;
                    _validarDatas();
                    FocusScope.of(context).unfocus();
                  },
                  style: TextStyle(
                    color: (inicioInvalidVisible || intervalInvalidVisible)
                        ? Colors.red[800]
                        : Colors.black,
                    backgroundColor: corIntervalo,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Data final
              Expanded(
                child: TextField(
                  controller: dataFimCtrl,
                  focusNode: fimFocusNode,
                  decoration: _decoracaoCampo(
                    label: "Data final",
                    invalido: fimInvalidVisible || intervalInvalidVisible,
                    onCalendario: () => _selecionarData(context, dataFimCtrl),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [dataMask],
                  onEditingComplete: () {
                    dataFimTouched = true;
                    _validarDatas();
                    FocusScope.of(context).unfocus();
                    // 🔹 BUSCA ao finalizar edição da data final
                    _executarBusca();
                  },
                  style: TextStyle(
                    color: (fimInvalidVisible || intervalInvalidVisible)
                        ? Colors.red[800]
                        : Colors.black,
                    backgroundColor: corIntervalo,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Linha de botões - Limpar Datas e Buscar
          // Linha de filtros e botões
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 🔹 Filtros de tipo (lado esquerdo)
              Row(
                children: [
                  Checkbox(
                    value: filtroParcelamento,
                    onChanged: (val) {
                      setState(() => filtroParcelamento = val ?? false);
                      _executarBusca();
                    },
                  ),
                  const Text("Parcelamento"),
                  const SizedBox(width: 16),
                  Checkbox(
                    value: filtroAmortizacao,
                    onChanged: (val) {
                      setState(() => filtroAmortizacao = val ?? false);
                      _executarBusca();
                    },
                  ),
                  const Text("Amortização"),
                ],
              ),

              // 🔹 Botões de ação (lado direito)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _limparDatas,
                    icon: const Icon(Icons.cleaning_services, size: 18),
                    label: const Text("Limpar Datas"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[400]!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _executarBusca,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text("Buscar"),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Corpo dinâmico — relatório selecionado
          Expanded(child: _buildRelatorio()),
        ],
      ),
    );
  }
}