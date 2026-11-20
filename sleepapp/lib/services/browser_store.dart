import 'browser_store_stub.dart'
    if (dart.library.html) 'browser_store_web.dart'
    as store;

String? browserRead(String key) => store.read(key);
void browserWrite(String key, String value) => store.write(key, value);
