import 'package:flutter/cupertino.dart';

import '../shared/food_style.dart';

class MeDetailPage extends StatelessWidget {
  const MeDetailPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => FoodStyle.theme(
    CupertinoPageScaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: MediaQuery.textScalerOf(context).scale(22) + 28,
                    child: NavigationToolbar(
                      leading: CupertinoButton(
                        key: const Key('page-back'),
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.chevron_back,
                              size: 22,
                              color: FoodStyle.ink,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Me',
                              style: TextStyle(
                                color: FoodStyle.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      middle: Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class MeDetailCard extends StatelessWidget {
  const MeDetailCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: FoodStyle.surface,
      borderRadius: BorderRadius.all(Radius.circular(18)),
      boxShadow: [
        BoxShadow(
          color: Color(0x102C4431),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}
