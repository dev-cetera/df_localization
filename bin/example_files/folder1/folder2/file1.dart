import 'package:df_localization/df_localization.dart';

void example() {
  'User Name||user.name'.tr(
      //
      );
  'User ID||user.id'
      //
      .tr();
  'User Email||user.email'.tr();
  'User URL: {url}||user.metadata.url'.tr(
    args: {'url': 'https://example.com'},
  );
}
