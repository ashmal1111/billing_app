import 'app_storage_base.dart';
import 'app_storage_stub.dart'
    if (dart.library.io) 'app_storage_io.dart'
    if (dart.library.html) 'app_storage_web.dart';

export 'app_storage_base.dart';

AppStorage createAppStorage() => createPlatformStorage();
