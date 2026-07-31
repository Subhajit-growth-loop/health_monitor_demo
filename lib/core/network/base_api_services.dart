import 'dart:io';

abstract class BaseApiServices {
  Future<dynamic> getGetApiResponse(String url, {String? token, Map<String, dynamic>? queryParams});
  Future<dynamic> getPostApiResponse(String url, dynamic data, {String? token});
  Future<dynamic> putApiResponse(String url, dynamic data, {String? token});
  Future<dynamic> deleteApiResponse(String url, {String? token});
  Future<dynamic> getPatchApiResponse(String url, {dynamic data, String? token});
  Future<dynamic> postMultipartFile(String url, File file, String fieldName, {String? token});
}
