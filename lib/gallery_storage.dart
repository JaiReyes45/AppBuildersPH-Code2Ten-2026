import 'gallery_storage_api.dart';
import 'gallery_storage_stub.dart'
    if (dart.library.io) 'gallery_storage_io.dart'
    as platform;

export 'gallery_storage_api.dart';

Future<GalleryStorage> createGalleryStorage() =>
    platform.createGalleryStorage();
