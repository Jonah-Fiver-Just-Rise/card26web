import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

class CardThumbnail extends StatelessWidget {
  final String? imageUrl;
  final String? catalogId;
  final double width;
  final double height;

  const CardThumbnail({
    super.key,
    this.imageUrl,
    this.catalogId,
    this.width = 50,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    // Check if we have base64 custom image
    if (imageUrl != null && imageUrl!.startsWith('data:image')) {
      try {
        final base64Str = imageUrl!.split(',').last;
        final bytes = base64Decode(base64Str);
        imageWidget = Padding(
          padding: const EdgeInsets.all(2.0),
          child: Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.contain,
          ),
        );
      } catch (e) {
        imageWidget = _buildFallbackLogo();
      }
    } 
    // Check if we have regular URL
    else if (imageUrl != null && imageUrl!.isNotEmpty) {
      imageWidget = Padding(
        padding: const EdgeInsets.all(2.0),
        child: Image.network(
          imageUrl!,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingIndicator();
          },
        ),
      );
    } 
    // Check if we have catalog ID to fetch from CardSight API
    else if (catalogId != null && catalogId!.isNotEmpty) {
      final cardSightKey = AppConstants.cardSightApiKey;
      final headers = <String, String>{};
      if (cardSightKey != "YOUR_CARDSIGHT_API_KEY" && cardSightKey.isNotEmpty) {
        headers["X-API-Key"] = cardSightKey;
      }
      imageWidget = Padding(
        padding: const EdgeInsets.all(2.0),
        child: Image.network(
          "https://api.cardsight.ai/v1/images/cards/$catalogId",
          headers: headers,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingIndicator();
          },
        ),
      );
    } 
    // Default fallback
    else {
      imageWidget = _buildFallbackLogo();
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget,
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.style_outlined,
            color: AppColors.textMuted.withOpacity(0.5),
            size: 20,
          ),
          const SizedBox(height: 2),
          Text(
            "KARTIS",
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted.withOpacity(0.6),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.gold.withOpacity(0.5),
        ),
      ),
    );
  }
}
