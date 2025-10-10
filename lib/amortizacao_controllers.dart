import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'amortizacao_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AmortizacaoControllers {
  final AmortizacaoService _service = AmortizacaoService();
  
  // 🔹 DADOS DA TABELA
  final List<Map<String, dynamic>> _linhas = [];
  final List<Map<String, TextEditingController>> _controllers = [];
  
  // 🔹 CONTROLE DE TAXA DE JUROS
  final TextEditingController taxaJurosCtrl = TextEditingController();
  double _taxaJuros = 0.0;

  // 🔹 GETTERS PARA ACESSO EXTERNO
  List<Map<String, dynamic>> get linhas => _linhas;
  List<Map<String, TextEditingController>> get controllers => _controllers;
  double get taxaJuros => _taxaJuros;
  set taxaJuros(double value) => _taxaJuros = value;

  // 🔹 MÉTODOS DE FORMATAÇÃO (delegados para o service)
  String fmtMoeda(double valor) => _service.fmtMoeda(valor);
  double parseMoeda(String texto) => _service.parseMoeda(texto);

  AmortizacaoControllers() {
    _inicializarPrimeiraLinha();
  }

  void _inicializarPrimeiraLinha() {
    _linhas.add({
      'data': DateFormat('dd/MM/yyyy').format(DateTime.now()),
      'saldo_inicial': 0.0,
      'aporte': 0.0,
      'pg_capital': 0.0,
      'pg_juros': 0.0,
      'juros_mes': 0.0,
      'saldo_final': 0.0,
    });
    _preencherControllers();
  }

  void _preencherControllers() {
    _controllers.clear();
    for (final linha in _linhas) {
      _controllers.add({
        'data': TextEditingController(text: linha['data'].toString()),
        'aporte': TextEditingController(text: fmtMoeda(linha['aporte'])),
        'pg_capital': TextEditingController(text: fmtMoeda(linha['pg_capital'])),
        'pg_juros': TextEditingController(text: fmtMoeda(linha['pg_juros'])),
        'juros_mes': TextEditingController(text: fmtMoeda(linha['juros_mes'])),
      });
    }
  }

  // 🔹 CARREGAR PARCELAS DO BANCO
  Future<void> carregarParcelasDoBanco(String idEmprestimo) async {
    final parcelas = await _service.buscarParcelasAmortizacao(idEmprestimo);
    
    if (parcelas.isNotEmpty) {
      _linhas.clear();
      _linhas.addAll(parcelas);
      _preencherControllers();
      recalcularSaldos(); // Recalcula saldos iniciais/finais
    }
  }

  // 🔹 SALVAR PARCELAS NO BANCO
  Future<bool> salvarParcelasNoBanco(String idEmprestimo) async {
    // Atualiza dados das linhas com valores dos controllers antes de salvar
    for (int i = 0; i < _linhas.length; i++) {
      final controller = _controllers[i];
      _linhas[i]['aporte'] = parseMoeda(controller['aporte']!.text);
      _linhas[i]['pg_capital'] = parseMoeda(controller['pg_capital']!.text);
      _linhas[i]['pg_juros'] = parseMoeda(controller['pg_juros']!.text);
      _linhas[i]['juros_mes'] = parseMoeda(controller['juros_mes']!.text);
      _linhas[i]['data'] = controller['data']!.text;
    }

    final userId = _getUserId();
    if (userId == null) {
      print('Erro: Usuário não autenticado');
      return false;
    }

    return await _service.salvarParcelasAmortizacao(
      idEmprestimo, 
      _linhas, 
      userId
    );
  }

  String? _getUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (e) {
      return null;
    }
  }

  // 🔹 ADICIONAR NOVA LINHA
  void adicionarLinha() {
    final double ultimoSaldoFinal = _linhas.isNotEmpty 
        ? (_linhas.last['saldo_final'] ?? 0.0) 
        : 0.0;

    _linhas.add({
      'data': '',
      'saldo_inicial': ultimoSaldoFinal,
      'aporte': 0.0,
      'pg_capital': 0.0,
      'pg_juros': 0.0,
      'juros_mes': 0.0,
      'saldo_final': ultimoSaldoFinal,
    });

    _controllers.add({
      'data': TextEditingController(),
      'aporte': TextEditingController(),
      'pg_capital': TextEditingController(),
      'pg_juros': TextEditingController(),
      'juros_mes': TextEditingController(),
    });

    recalcularSaldos();
  }

  // 🔹 VERIFICAR SE HÁ DATA VAZIA
  bool haDataVazia() {
    for (final controller in _controllers) {
      if (controller['data']!.text.isEmpty) {
        return true;
      }
    }
    return false;
  }

  // 🔹 RECALCULAR SALDOS
  void recalcularSaldos() {
    for (int i = 0; i < _linhas.length; i++) {
      final linha = _linhas[i];
      final controller = _controllers[i];
      
      // Atualiza os valores das linhas com os dados dos controllers
      linha['aporte'] = parseMoeda(controller['aporte']!.text);
      linha['pg_capital'] = parseMoeda(controller['pg_capital']!.text);
      linha['pg_juros'] = parseMoeda(controller['pg_juros']!.text);
      linha['juros_mes'] = parseMoeda(controller['juros_mes']!.text);
      linha['data'] = controller['data']!.text;

      final double saldoInicial = linha['saldo_inicial'] ?? 0.0;
      final double aporte = linha['aporte'] ?? 0.0;
      final double pgCapital = linha['pg_capital'] ?? 0.0;
      final double pgJuros = linha['pg_juros'] ?? 0.0;
      final double jurosMes = linha['juros_mes'] ?? 0.0;

      linha['saldo_final'] = saldoInicial + aporte - pgCapital - pgJuros + jurosMes;

      // Propaga saldo final para próxima linha (saldo inicial)
      if (i < _linhas.length - 1) {
        _linhas[i + 1]['saldo_inicial'] = linha['saldo_final'];
      }
    }
  }

  // 🔹 CALCULAR JUROS AUTOMATICAMENTE
  void calcularJurosAutomatico(int index) {
    if (index == 0) return; // Primeira linha não tem linha anterior
    
    final dataAtual = _controllers[index]['data']!.text;
    final dataAnterior = _controllers[index - 1]['data']!.text;
    
    // Só calcula se ambas as datas estiverem preenchidas (dd/mm/aaaa)
    if (dataAtual.length == 10 && dataAnterior.length == 10) {
      final diferencaDias = _service.calcularDiferencaDias(dataAnterior, dataAtual);
      
      if (diferencaDias > 0 && _taxaJuros > 0) {
        final saldoAnterior = _linhas[index - 1]['saldo_final'] ?? 0.0;
        final jurosCalculado = saldoAnterior * (_taxaJuros / 100 / 30) * diferencaDias;
        
        // Atualiza o campo de juros apenas se estiver vazio
        final jurosAtual = parseMoeda(_controllers[index]['juros_mes']!.text);
        if (jurosAtual == 0.0) {
          _controllers[index]['juros_mes']!.text = fmtMoeda(jurosCalculado);
          _linhas[index]['juros_mes'] = jurosCalculado;
          recalcularSaldos();
        }
      }
    }
  }

  // 🔹 RECALCULAR TODOS OS JUROS DA PLANILHA
  void recalcularTodosJuros() {
    for (int i = 1; i < _linhas.length; i++) {
      final dataAtual = _controllers[i]['data']!.text;
      final dataAnterior = _controllers[i - 1]['data']!.text;
      
      if (dataAtual.length == 10 && dataAnterior.length == 10) {
        final diferencaDias = _service.calcularDiferencaDias(dataAnterior, dataAtual);
        
        if (diferencaDias > 0 && _taxaJuros > 0) {
          final saldoAnterior = _linhas[i - 1]['saldo_final'] ?? 0.0;
          final jurosCalculado = saldoAnterior * (_taxaJuros / 100 / 30) * diferencaDias;
          
          _controllers[i]['juros_mes']!.text = fmtMoeda(jurosCalculado);
          _linhas[i]['juros_mes'] = jurosCalculado;
        }
      }
    }
    recalcularSaldos();
  }

  // 🔹 LIMPAR RECURSOS (importante para evitar memory leaks)
  void dispose() {
    for (final controllerMap in _controllers) {
      controllerMap['data']?.dispose();
      controllerMap['aporte']?.dispose();
      controllerMap['pg_capital']?.dispose();
      controllerMap['pg_juros']?.dispose();
      controllerMap['juros_mes']?.dispose();
    }
    taxaJurosCtrl.dispose();
  }

  // 🔹 VALIDAR DADOS ANTES DE SALVAR
  bool validarDados() {
    // Verifica se todas as datas estão preenchidas
    for (final controller in _controllers) {
      if (controller['data']!.text.isEmpty) {
        return false;
      }
    }

    // Verifica se as datas estão em ordem crescente
    for (int i = 1; i < _controllers.length; i++) {
      final dataAnterior = _controllers[i - 1]['data']!.text;
      final dataAtual = _controllers[i]['data']!.text;
      
      if (dataAnterior.isNotEmpty && dataAtual.isNotEmpty) {
        final dias = _service.calcularDiferencaDias(dataAnterior, dataAtual);
        if (dias < 0) {
          return false; // Data anterior é maior que data atual
        }
      }
    }

    return true;
  }

  // 🔹 CALCULAR TOTAL GERAL
  Map<String, double> calcularTotais() {
    double totalAporte = 0;
    double totalPgCapital = 0;
    double totalPgJuros = 0;
    double totalJurosPeriodo = 0;

    for (var i = 0; i < _linhas.length; i++) {
      totalAporte += parseMoeda(_controllers[i]['aporte']!.text);
      totalPgCapital += parseMoeda(_controllers[i]['pg_capital']!.text);
      totalPgJuros += parseMoeda(_controllers[i]['pg_juros']!.text);
      totalJurosPeriodo += parseMoeda(_controllers[i]['juros_mes']!.text);
    }

    return {
      'aporte': totalAporte,
      'pg_capital': totalPgCapital,
      'pg_juros': totalPgJuros,
      'juros_periodo': totalJurosPeriodo,
      'saldo_final': _linhas.isNotEmpty ? (_linhas.last['saldo_final'] ?? 0.0) : 0.0,
    };
  }
}