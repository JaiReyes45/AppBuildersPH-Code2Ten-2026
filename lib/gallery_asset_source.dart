import 'package:photo_manager/photo_manager.dart';

import 'gallery_storage_api.dart' show DateTimeRange;

/// Small native boundary so paging/permission behavior can be tested offline.
class GalleryAssetSource {
  Future<bool> requestPermission() async =>
      (await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      )).hasAccess;

  Future<List<AssetEntity>> page({
    required int page,
    required int size,
    DateTimeRange? range,
  }) => PhotoManager.getAssetListPaged(
    page: page,
    pageCount: size,
    type: RequestType.image,
    filterOption: FilterOptionGroup(
      createTimeCond: range == null
          ? null
          : DateTimeCond(
              // Native timestamp resolution differs by platform. Check exact
              // inclusive bounds again in Dart after fetching this wider window.
              min: range.start.subtract(const Duration(seconds: 1)),
              max: range.end.add(const Duration(seconds: 1)),
            ),
      orders: const [OrderOption(type: OrderOptionType.createDate, asc: false)],
    ),
  );
}
