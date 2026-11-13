import 'package:supabase_flutter/supabase_flutter.dart';

bool validReferralDownloadUrl(String value) {
  final url = Uri.tryParse(value);
  return value.length <= 2048 &&
      value.isNotEmpty &&
      !RegExp(r'[\s\\]').hasMatch(value) &&
      url != null &&
      url.scheme == 'https' &&
      url.host.isNotEmpty &&
      url.userInfo.isEmpty;
}

class ReferralDownloadGateway {
  const ReferralDownloadGateway(this.client);
  final SupabaseClient client;

  Future<String?> load() async {
    final rows = await client
        .from('referral_download_link')
        .select('url')
        .limit(1);
    if (rows.isEmpty) return null;
    final url = rows.first['url'] as String;
    if (!validReferralDownloadUrl(url)) {
      throw const FormatException('Invalid URL');
    }
    return url;
  }

  Future<void> save(String? url) async {
    await client.rpc(
      'admin_set_referral_download_link',
      params: {'p_url': url},
    );
  }
}
