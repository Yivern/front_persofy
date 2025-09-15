import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio();
  final String _apiBaseUrl = "http://confidencial:8030";

  Future<List<dynamic>> searchSongs(String query) async {
    try {
      final response = await _dio.get(
        "$_apiBaseUrl/api/persofy/v1/search",
        queryParameters: {"query": query, "limit": 10},
      );
      return response.data;
    } catch (e) {
      print("Error en ApiService.searchSongs: $e");
      throw Exception('Error al buscar canciones: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getStreamInfo(String youtubeUrl) async {
    try {
      final response = await _dio.get(
        "$_apiBaseUrl/api/persofy/v1/stream",
        queryParameters: {"query": youtubeUrl},
      );
      return response.data;
    } catch (e) {
      print("Error en ApiService.getStreamInfo: $e");
      throw Exception('Error al obtener el stream: ${e.toString()}');
    }
  }
}
