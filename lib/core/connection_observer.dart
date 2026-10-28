import 'package:flutter/foundation.dart';

enum ConnectionStatus { online, offline }

class ConnectionObserver extends ValueNotifier<ConnectionStatus> {
  ConnectionObserver._() : super(ConnectionStatus.online);

  static final ConnectionObserver instance = ConnectionObserver._();

  void markOffline() {
    if (value == ConnectionStatus.offline) return;
    value = ConnectionStatus.offline;
  }

  void markOnline() {
    if (value == ConnectionStatus.online) return;
    value = ConnectionStatus.online;
  }

  void refresh() {
    markOnline();
  }
}
