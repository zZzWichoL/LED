import 'dart:io';
import 'dart:convert';
import 'dart:async';

class ConnectionSettings {
  String? _host;
  int? _port;

  Future<void> connect(String host, int port) async {
    // Solo guarda los datos, no abre ningún socket aquí
    _host = host;
    _port = port;
  }

  Future<String> sendCommand(String command) async {
    if (_host == null || _port == null) {
      throw Exception('No hay datos de conexión guardados');
    }

    // Abre una nueva conexión para cada comando
    Socket socket =
        await Socket.connect(_host!, _port!, timeout: Duration(seconds: 5));
    final completer = Completer<String>();
    List<int> buffer = [];

    late StreamSubscription sub;
    sub = socket.listen(
      (data) {
        buffer.addAll(data);
        String response = utf8.decode(buffer).trim();
        if (!completer.isCompleted) {
          completer.complete(response);
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError('Conexión cerrada sin respuesta');
        }
      },
      cancelOnError: true,
    );

    socket.write('$command\n');
    await socket.flush();

    try {
      String response = await completer.future.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('No se recibió respuesta en 5 segundos');
        },
      );
      await sub.cancel();
      await socket.close();
      return response;
    } catch (e) {
      await sub.cancel();
      await socket.close();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    // No hay nada que desconectar porque no hay socket global
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
