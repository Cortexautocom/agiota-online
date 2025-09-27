import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cliente.dart';

class ClientesService {
  final supabase = Supabase.instance.client;

  Future<List<Cliente>> carregarClientes() async {
    final response = await supabase.from('clientes').select();
    final data = response as List<dynamic>;
    return data.map((c) => Cliente.fromMap(c)).toList();
  }

  Future<void> adicionarCliente(Cliente cliente) async {
    await supabase.from('clientes').insert(cliente.toMap());
  }

  Future<void> excluirCliente(String idCliente) async {
    await supabase.from('clientes').delete().eq('id_cliente', idCliente);
  }
}
