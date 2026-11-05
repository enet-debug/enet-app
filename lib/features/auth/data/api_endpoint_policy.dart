/// Shared validation for user-selected eNet API endpoints.
///
/// Internet traffic must always use HTTPS. Plain HTTP is permitted only for
/// development against a loopback server on the same device.
abstract final class ApiEndpointPolicy {
  static String normalize(String raw) {
    final value = raw.trim();
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty || uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw const FormatException('Укажите адрес API без пути и параметров, например https://api.example.ru');
    }
    final local = uri.host == 'localhost' ||
        uri.host == '127.0.0.1' || uri.host == '[::1]' || uri.host == '::1';
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && local)) {
      throw const FormatException('Для удалённого сервера необходим HTTPS.');
    }
    return uri.origin;
  }
}
