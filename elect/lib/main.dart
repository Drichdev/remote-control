import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show
        Platform,
        InternetAddress,
        RawDatagramSocket,
        RawSocketEvent,
        WebSocket;
import 'package:elect/utils/testSyles.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'connect.dart';

void main() => runApp(RemoteApp());

class RemoteApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Télécommande PC',
        theme: ThemeData.light(),
        home: RemoteControlPage(),
      );
}

class RemoteControlPage extends StatefulWidget {
  @override
  _RemoteControlPageState createState() => _RemoteControlPageState();
}

class _RemoteControlPageState extends State<RemoteControlPage> {
  static const _wsPort = 8080;
  static const _udpPort = 41234;
  static const _token = 'mon_secret_partagé';

  String _name = 'FlutterPhone';
  bool _discovered = false;
  bool _connected = false;
  String _serverIp = '';

  RawDatagramSocket? _udp;
  Timer? _timer;
  WebSocketChannel? _ws;

  @override
  void initState() {
    super.initState();
    _attemptLocalWs();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _udp?.close();
    _ws?.sink.close(status.normalClosure);
    super.dispose();
  }

  String get _localHost {
    if (kIsWeb) return 'localhost';
    if (Platform.isAndroid) return '10.0.2.2'; // émulateur Android
    return 'localhost'; // iOS & desktop
  }

  void _attemptLocalWs() async {
    final ok = await _connectWs(_localHost);
    if (!ok && !kIsWeb)
      Future.delayed(Duration(seconds: 1), _startUdpDiscovery);
  }

  Future<bool> _connectWs(String ip) async {
    try {
      // nouvelle implémentation :
      final socket = await WebSocket.connect('ws://$ip:$_wsPort')
          .timeout(Duration(seconds: 1));
      final channel = IOWebSocketChannel(socket);

      channel.stream.listen(
        _onWsMessage,
        onDone: () => setState(() => _connected = false),
        onError: (_) => setState(() => _connected = false),
      );

      channel.sink.add(jsonEncode({
        'type': 'discover',
        'name': _name,
        'token': _token,
      }));

      setState(() {
        _ws = channel;
        _serverIp = ip;
      });
      return true;
    } catch (_) {
      // échec de la connexion WS
      return false;
    }
  }

  void _startUdpDiscovery() async {
    _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _udp!.broadcastEnabled = true;
    _udp!.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = _udp!.receive();
        if (dg == null) return;
        try {
          final obj = jsonDecode(utf8.decode(dg.data));
          if (obj['type'] == 'server-info' && obj['token'] == _token) {
            _timer?.cancel();
            _udp?.close();
            _connectWs(obj['ip'] as String);
          }
        } catch (_) {}
      }
    });

    final msg = jsonEncode({
      'type': 'discover',
      'name': _name,
      'token': _token,
    });
    _timer = Timer.periodic(Duration(milliseconds: 500), (_) {
      _udp!.send(
        utf8.encode(msg),
        InternetAddress('255.255.255.255'),
        _udpPort,
      );
    });
  }

  void _onWsMessage(dynamic data) {
    try {
      final obj = jsonDecode(data.toString());
      if (obj['type'] == 'discover_ok') {
        setState(() => _discovered = true);
        return;
      }
      if (obj['type'] == 'select_ok') {
        setState(() => _connected = true);
        return;
      }
      if (obj['type'] == 'disconnect_ok') {
        _ws?.sink.close(status.normalClosure);
        setState(() {
          _connected = false;
          _discovered = false;
          _serverIp = '';
        });
        Future.delayed(Duration(milliseconds: 100), _attemptLocalWs);
      }
    } catch (_) {}
  }

  void _sendCmd(String cmd) {
    if (_connected) _ws?.sink.add(cmd);
  }

  void _disconnect() {
    _ws?.sink.close(status.normalClosure);
    setState(() {
      _connected = false;
      _discovered = false;
      _serverIp = '';
    });
    Future.delayed(Duration(milliseconds: 100), _attemptLocalWs);
  }

  Future<void> _showManualConnect() async {
    final ctrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: MediaQuery.of(context).viewInsets + EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          mediumTextBlack('Connexion manuelle', Colors.black),
          SizedBox(height: 8),
          TextField(
            controller: ctrl,
            decoration: InputDecoration(labelText: 'Adresse IP'),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final ip = ctrl.text.trim();
                if (ip.isNotEmpty) {
                  Navigator.pop(context);
                  _timer?.cancel();
                  _udp?.close();
                  _connectWs(ip);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: btnTextBlack('Se connecter', Colors.white),
            ),
          ),
          SizedBox(height: 16),
        ]),
      ),
    );
  }

  Future<void> _showEditName() async {
    final ctrl = TextEditingController(text: _name);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: MediaQuery.of(context).viewInsets + EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          mediumTextBlack('Modifier le nom', Colors.black),
          SizedBox(height: 8),
          TextField(
              controller: ctrl, decoration: InputDecoration(labelText: 'Nom')),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final nm = ctrl.text.trim();
                if (nm.isNotEmpty) {
                  setState(() => _name = nm);
                  _ws?.sink.add(jsonEncode({
                    'type': 'discover',
                    'name': _name,
                    'token': _token,
                  }));
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: btnTextBlack('Valider', Colors.white),
            ),
          ),
          SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusTxt = !_discovered
        ? 'Déconnecté'
        : !_connected
            ? 'Découvert'
            : 'Connecté';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.circle,
                      size: 12, color: _discovered ? Colors.green : Colors.red),
                  label: smallTextBlack(statusTxt, Colors.black),
                  style: OutlinedButton.styleFrom(shape: StadiumBorder()),
                ),
                OutlinedButton.icon(
                  onPressed: _showEditName,
                  icon: Icon(Icons.edit, size: 18),
                  label: smallTextBlack(_name, Colors.black),
                  style: OutlinedButton.styleFrom(shape: StadiumBorder()),
                ),
              ],
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: _showManualConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: btnTextBlack('Connexion manuelle', Colors.white)),
            ),
            SizedBox(height: 32),
            Expanded(
              child: Center(child: RippleAnimation()),
            ),
            btnTextBlack('Commande', Colors.black),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: _connected ? () => _sendCmd('esc') : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.blue)),
                  ),
                  child: mediumTextBlack('ESC', Colors.black)),
            ),
            SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: ElevatedButton(
                onPressed: _connected ? () => _sendCmd('left') : null,
                child: Icon(Icons.arrow_left, size: 32),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.blue)),
                ),
              )),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                    onPressed: _connected ? () => _sendCmd('right') : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.blue)),
                    ),
                    child: Icon(Icons.arrow_right, size: 32)),
              ),
            ]),
            SizedBox(height: 24),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: btnTextBlack(
                      !_discovered
                          ? 'Recherche...'
                          : (!_connected
                              ? 'En attente de sélection'
                              : 'Connecté à $_serverIp'),
                      Colors.grey)),
            ),
            SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}
