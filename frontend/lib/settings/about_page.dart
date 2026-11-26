import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../shared/food_style.dart';
import 'me_detail_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final _version = _loadVersion();

  Future<String?> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version.isEmpty ? null : info.version;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => MeDetailPage(
    title: 'About us',
    children: [
      MeDetailCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Image.asset(
                'assets/images/Logo2.png',
                width: 220,
                height: 148,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
              const SizedBox(height: 8),
              const Text(
                'TrackTalk',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Food and activity diary',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: FoodStyle.forest),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      const MeDetailCard(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Log meals and activity by typing or speaking. Review your records and find food ideas based on what you log.',
            style: TextStyle(height: 1.45),
          ),
        ),
      ),
      const SizedBox(height: 14),
      MeDetailCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Version',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FutureBuilder<String?>(
                  future: _version,
                  builder: (context, snapshot) => Text(
                    snapshot.connectionState == ConnectionState.done
                        ? snapshot.data ?? 'Unavailable'
                        : 'Loading…',
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: FoodStyle.forest),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
