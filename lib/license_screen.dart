// 👶 このファイルは「ライセンス情報画面」のロジックです。
// - アプリで利用しているOSSライセンスや利用規約を表示します。

import 'package:flutter/material.dart';

class LicenseScreen extends StatelessWidget {
  const LicenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📄 ライセンス・出典')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Section(
            title: 'オープンデータ出典',
            body: '東京都防災マップ 避難場所・避難所オープンデータ\nhttps://catalog.data.metro.tokyo.lg.jp/dataset/t000003d0000000093',
          ),
          _Section(
            title: '利用ポリシー要約',
            body: '本アプリは災害支援を目的とした学習/検証利用であり、公式データの最新性・正確性を保証しません。実運用時は必ず公式情報を確認してください。',
          ),
          _Section(
            title: 'サードパーティライブラリ',
            body: 'Flutter / Firebase SDK / google_maps_flutter / geolocator / image_picker など OSS ライセンス (BSD / Apache / MIT)。\n詳細は Flutter AboutDialog でも参照可能。',
          ),
          _Section(
            title: '免責事項',
            body: '提供情報の利用によって発生した損害等について開発者は責任を負いません。',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
