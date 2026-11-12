import 'package:flutter/material.dart';
import '../../../../core/theme/km1.dart';

/// 商品を選ぶタイル（KM1）。カートに入っている数は、塗り・縁・「n 点」の文言で示す。
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.name,
    required this.price,
    required this.count,
    required this.onTap,
    this.large = false,
  });

  final String name;
  final int price;
  final int count;
  final VoidCallback onTap;

  /// お客様向け（文字を一段大きくする）
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final selected = count > 0;
    return Semantics(
      button: true,
      label: '$name、$price 円${selected ? '、$count 点選択中' : ''}',
      child: Material(
        color: selected ? c.brandTint : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Km1Radius.lg),
          side: BorderSide(
            color: selected ? c.brandStroke : c.stroke,
            width: selected ? Km1Size.strokeThick : Km1Size.strokeThin,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: c.surfaceHover,
          child: Stack(children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(Km1Space.sm),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name,
                        style: (large ? Km1Text.subtitle2 : Km1Text.body1Strong)
                            .copyWith(color: c.ink),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: Km1Space.xs),
                    Text('¥$price',
                        style: (large ? Km1Text.body2 : Km1Text.body1)
                            .copyWith(color: c.inkSecondary)),
                  ],
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: Km1Space.sm,
                right: Km1Space.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Km1Space.smNudge),
                  decoration: BoxDecoration(
                    color: c.brand,
                    borderRadius: BorderRadius.circular(Km1Radius.circular),
                  ),
                  child: Text('$count 点',
                      style: Km1Text.caption1
                          .copyWith(color: c.onBrand, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// カートの 1 行（商品名・増減・小計）
class CartRow extends StatelessWidget {
  const CartRow({
    super.key,
    required this.name,
    required this.quantity,
    required this.subtotal,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String name;
  final int quantity;
  final int subtotal;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    const tabular = [FontFeature.tabularFigures()];
    return Row(children: [
      Expanded(
        child: Text(name,
            style: Km1Text.body1.copyWith(color: c.ink),
            overflow: TextOverflow.ellipsis),
      ),
      IconButton(
        icon: const Icon(Km1Icons.subtractCircle),
        tooltip: '$nameを 1 つ減らす',
        onPressed: onDecrease,
      ),
      SizedBox(
        width: 32,
        child: Text('$quantity',
            textAlign: TextAlign.center,
            style: Km1Text.subtitle2.copyWith(color: c.ink, fontFeatures: tabular)),
      ),
      IconButton(
        icon: const Icon(Km1Icons.addCircle),
        tooltip: '$nameを 1 つ増やす',
        onPressed: onIncrease,
      ),
      SizedBox(
        width: 72,
        child: Text('¥$subtotal',
            textAlign: TextAlign.right,
            style: Km1Text.body1.copyWith(color: c.ink, fontFeatures: tabular)),
      ),
    ]);
  }
}
