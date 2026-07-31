import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/services/base_api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/user_stats.dart';

class StatsService extends BaseApiService {
  Future<UserStats> getMyStats() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.userUrl}/stats/me'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) return UserStats.fromJson(jsonDecode(res.body));
    throwFromResponse(res, 'errors.stats_load'.tr());
  }

  Future<UserStats> getUserStats(String username) async {
    final res = await http.get(
      Uri.parse('${ApiConstants.userUrl}/stats/$username'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) return UserStats.fromJson(jsonDecode(res.body));
    throwFromResponse(res, 'errors.stats_load'.tr());
  }
}
