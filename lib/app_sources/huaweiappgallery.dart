import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:obtainium/custom_errors.dart';
import 'package:obtainium/providers/source_provider.dart';

class HuaweiAppGallery extends AppSource {
  HuaweiAppGallery() {
    name = 'Huawei AppGallery';
    hosts = ['appgallery.huawei.com'];
    versionDetectionDisallowed = true;
    showReleaseDateAsVersionToggle = true;
  }

  @override
  String sourceSpecificStandardizeURL(String url) {
    RegExp standardUrlRegEx = RegExp(
        '^https?://(www\\.)?${getSourceRegex(hosts)}/app/[^/]+',
        caseSensitive: false);
    RegExpMatch? match = standardUrlRegEx.firstMatch(url);
    if (match == null) {
      throw InvalidURLError(name);
    }
    return match.group(0)!;
  }

  getDlUrl(String standardUrl) =>
      'https://${hosts[0].replaceAll('appgallery.', 'appgallery.cloud.')}/appdl/${standardUrl.split('/').last}';

  requestAppdlRedirect(
      String dlUrl, Map<String, dynamic> additionalSettings) async {
    Response res =
        await sourceRequest(dlUrl, additionalSettings, followRedirects: false);
    if (res.statusCode == 200 ||
        res.statusCode == 302 ||
        res.statusCode == 304) {
      return res;
    } else {
      throw getObtainiumHttpError(res);
    }
  }

  appIdFromRedirectDlUrl(String redirectDlUrl) {
    var parts = redirectDlUrl
        .split('?')[0]
        .split('/')
        .last
        .split('.')
        .reversed
        .toList();
    parts.removeAt(0);
    parts.removeAt(0);
    return parts.reversed.join('.');
  }

  @override
  Future<String?> tryInferringAppId(String standardUrl,
      {Map<String, dynamic> additionalSettings = const {}}) async {
    String dlUrl = getDlUrl(standardUrl);
    Response res = await requestAppdlRedirect(dlUrl, additionalSettings);
    return res.headers.map['location']?.isNotEmpty == true
        ? appIdFromRedirectDlUrl(res.headers.map['location']![0])
        : null;
  }

  @override
  Future<APKDetails> getLatestAPKDetails(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    String dlUrl = getDlUrl(standardUrl);
    Response res = await requestAppdlRedirect(dlUrl, additionalSettings);
    if (res.headers['location'] == null) {
      throw NoReleasesError();
    }
    String appId = appIdFromRedirectDlUrl(res.headers.map['location']![0]);
    var relDateStr = res.headers.map['location']?[0]
        .split('?')[0]
        .split('.')
        .reversed
        .toList()[1];
    var relDateStrAdj = relDateStr?.split('');
    var tempLen = relDateStrAdj?.length ?? 0;
    var i = 2;
    while (i < tempLen) {
      relDateStrAdj?.insert((i + i ~/ 2 - 1), '-');
      i += 2;
    }
    var relDate = relDateStrAdj == null
        ? null
        : DateFormat('yy-MM-dd-HH-mm').parse(relDateStrAdj.join(''));
    if (relDateStr == null) {
      throw NoVersionError();
    }
    return APKDetails(
        relDateStr, [MapEntry('$appId.apk', dlUrl)], AppNames(name, appId),
        releaseDate: relDate);
  }
}
