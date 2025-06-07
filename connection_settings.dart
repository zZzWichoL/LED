import 'dart:io';
import 'dart:convert';
import 'dart:async';

class ConnectionSettings {
  Socket? _socket;
  bool _isConnected = false;
  String? _host;
  int? _port;
  StreamSubscription? _subscription;

  bool get isConnected => _isConnected;

  Future<void> connect(String host, int port) async {
    print('⭐ Iniciando conexión a $host:$port');
    await disconnect(); // Limpiamos conexiones anteriores

    _host = host;
    _port = port;

    try {
      print('📡 Conectando socket...');
      _socket = await Socket.connect(
        host,
        port,
        timeout: Duration(seconds: 10),
      );

      _socket!.setOption(SocketOption.tcpNoDelay, true);
      _isConnected = true;
      print('✅ Conectado exitosamente a $host:$port');
    } catch (e) {
      _isConnected = false;
      print('❌ Error de conexión: $e');
      rethrow;
    }
  }

  Future<String> sendCommand(String command) async {
    if (!_isConnected || _socket == null) {
      await connect(_host!, _port!);
    }

    // Cancelamos cualquier suscripción anterior
    await _subscription?.cancel();
    _subscription = null;

    try {
      print('📤 Enviando comando: $command');
      final completer = Completer<String>();
      List<int> buffer = [];

      _subscription = _socket!.listen(
        (data) {
          buffer.addAll(data);
          String response = utf8.decode(buffer).trim();
          print('📥 Respuesta recibida: $response');
          if (!completer.isCompleted) {
            completer.complete(response);
          }
        },
        onError: (error) {
          print('❌ Error en socket: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        cancelOnError: true,
      );

      // Enviamos el comando
      _socket!.write('$command\n');
      await _socket!.flush();

      // Esperamos la respuesta con timeout
      final response = await completer.future.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('No se recibió respuesta en 5 segundos');
        },
      );

      // Cancelamos la suscripción después de recibir la respuesta
      await _subscription?.cancel();
      _subscription = null;

      return response;
    } catch (e) {
      print('❌ Error enviando comando: $e');
      _isConnected = false;
      await disconnect();
      throw Exception('Error: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _subscription?.cancel();
      _subscription = null;

      if (_socket != null) {
        await _socket!.close();
        _socket = null;
      }
      _isConnected = false;
      print('👋 Desconectado');
    } catch (e) {
      print('❌ Error al desconectar: $e');
    }
  }

  Future<bool> ping() async {
    try {
      String response = await sendCommand('PING');
      return response.contains('PONG');
    } catch (e) {
      return false;
    }
  }
}
