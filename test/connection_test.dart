import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/connection_observer.dart';

void main() {
  test('по умолчанию связь есть', () {
    ConnectionObserver.instance.markOnline();
    expect(ConnectionObserver.instance.value, ConnectionStatus.online);
  });

  test('сбой переводит в офлайн', () {
    ConnectionObserver.instance.markOffline();
    expect(ConnectionObserver.instance.value, ConnectionStatus.offline);
  });

  test('повтор возвращает онлайн', () {
    ConnectionObserver.instance.markOffline();
    ConnectionObserver.instance.refresh();
    expect(ConnectionObserver.instance.value, ConnectionStatus.online);
  });

  test('повторное офлайн-событие не меняет состояние', () {
    ConnectionObserver.instance.markOffline();
    ConnectionObserver.instance.markOffline();
    expect(ConnectionObserver.instance.value, ConnectionStatus.offline);
    ConnectionObserver.instance.markOnline();
  });
}
