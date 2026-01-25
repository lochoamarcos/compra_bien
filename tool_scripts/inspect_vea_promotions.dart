import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final url = Uri.parse('https://www.vea.com.ar/_v/getPromotions');
  print('Fetching Vea Promotions...');
  
  final res = await http.get(url, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://www.vea.com.ar/'
  });
  
  if (res.statusCode == 200) {
      // It might be JSON or JS
      print('Response Status: ${res.statusCode}');
      try {
        final data = json.decode(res.body);
        print(JsonEncoder.withIndent('  ').convert(data));
      } catch (e) {
          print('Not JSON? Body preview: ${res.body.substring(0, 500)}');
      }
  } else {
      print('Failed: ${res.statusCode}');
  }
}
