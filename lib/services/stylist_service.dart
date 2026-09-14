import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ----------------------------------------------------------------
// 🎯 خادم المصمم الذكي — Vercel endpoint
// ----------------------------------------------------------------
const String stylistServerUrl = 'https://alafif-notification-server.vercel.app/api/stylist';
// مفتاح API المشترك (نفس API_KEY المضبوط في Vercel → production)
const String stylistApiKey = 'd66d9f728e4731afb2493ea361f20305c13f38f9ce51261f';

/// منتج مختار من المصمم الذكي
class StylistPick {
  final String productId;
  final String size;
  final double price;

  const StylistPick({
    required this.productId,
    required this.size,
    required this.price,
  });

  factory StylistPick.fromJson(Map<String, dynamic> json) => StylistPick(
        productId: json['product_id'] ?? '',
        size: json['size'] ?? '',
        price: ((json['price'] ?? 0) as num).toDouble(),
      );
}

/// الإطلالة الكاملة من المصمم الذكي
class StylistOutfit {
  final String outfitTitle;
  final String stylistReasoning;
  final double totalPrice;
  final List<StylistPick> selectedProducts;

  const StylistOutfit({
    required this.outfitTitle,
    required this.stylistReasoning,
    required this.totalPrice,
    required this.selectedProducts,
  });

  factory StylistOutfit.fromJson(Map<String, dynamic> json) => StylistOutfit(
        outfitTitle: json['outfit_title'] ?? '',
        stylistReasoning: json['stylist_reasoning'] ?? '',
        totalPrice: ((json['total_price'] ?? 0) as num).toDouble(),
        selectedProducts: ((json['selected_products'] as List<dynamic>?) ?? [])
            .map((e) => StylistPick.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// تفضيلات المستخدم المُرسلة للمصمم الذكي
class StylistPreferences {
  final String occasion;
  final String style;
  final double budget;
  final String size;
  final List<String> colorHints;

  const StylistPreferences({
    this.occasion = 'يومي',
    this.style = '',
    this.budget = 50000,
    this.size = 'L',
    this.colorHints = const [],
  });

  Map<String, dynamic> toJson() => {
        'occasion': occasion,
        'style': style,
        'budget': budget,
        'size': size,
        'colorHints': colorHints,
      };
}

/// خدمة المصمم الذكي — تتواصل مع Vercel backend (DeepSeek)
class StylistService {
  /// يطلب إطلالة من المصمم الذكي
  static Future<StylistOutfit> generateOutfit({
    required StylistPreferences preferences,
    required List<Map<String, dynamic>> filteredProducts,
  }) async {
    final response = await http
        .post(
          Uri.parse(stylistServerUrl),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': stylistApiKey,
          },
          body: jsonEncode({
            'userPreferences': preferences.toJson(),
            'filteredProducts': filteredProducts,
          }),
        )
        .timeout(const Duration(seconds: 45));

    debugPrint('🎨 Stylist server response: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw Exception('فشل المصمم الذكي (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['ok'] != true || body['outfit'] == null) {
      throw Exception('استجابة غير صالحة من المصمم');
    }
    return StylistOutfit.fromJson(
        Map<String, dynamic>.from(body['outfit'] as Map));
  }
}
