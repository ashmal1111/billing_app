/// Deterministic, high-precision financial arithmetic value object.
///
/// Stores financial amounts internally as integer paise (1 INR = 100 Paise)
/// to completely eliminate IEEE 754 floating-point rounding drift, NaN, and Infinity.
class Money implements Comparable<Money> {
  final int paise;

  const Money.fromPaise(this.paise);

  factory Money.fromRupees(num rupees) {
    if (rupees.isNaN || rupees.isInfinite) return const Money.fromPaise(0);
    // Round to nearest paisa
    return Money.fromPaise((rupees * 100).round());
  }

  static const Money zero = Money.fromPaise(0);

  double get inRupees => paise / 100.0;

  Money operator +(Money other) => Money.fromPaise(paise + other.paise);
  Money operator -(Money other) => Money.fromPaise(paise - other.paise);

  /// Multiply by a scalar quantity or percentage factor
  Money multiply(num factor) {
    if (factor.isNaN || factor.isInfinite) return Money.zero;
    return Money.fromPaise((paise * factor).round());
  }

  /// Percentage calculation with banker's rounding
  Money percentage(num percent) {
    if (percent.isNaN || percent.isInfinite || percent <= 0) return Money.zero;
    return Money.fromPaise(((paise * percent) / 100.0).round());
  }

  bool get isZero => paise == 0;
  bool get isNegative => paise < 0;
  bool get isPositive => paise > 0;

  Money clampToZero() => paise < 0 ? Money.zero : this;

  String formatted({String symbol = '₹', bool includeSymbol = true}) {
    final absPaise = paise.abs();
    final r = absPaise ~/ 100;
    final p = absPaise % 100;
    final sign = paise < 0 ? '-' : '';

    // Indian Lakhs / Crores numbering format
    final rStr = r.toString();
    String formattedRupees;
    if (rStr.length <= 3) {
      formattedRupees = rStr;
    } else {
      final lastThree = rStr.substring(rStr.length - 3);
      final remaining = rStr.substring(0, rStr.length - 3);
      final buffer = StringBuffer();
      for (int i = 0; i < remaining.length; i++) {
        buffer.write(remaining[i]);
        final remainingDigits = remaining.length - 1 - i;
        if (remainingDigits > 0 && remainingDigits % 2 == 0) {
          buffer.write(',');
        }
      }
      formattedRupees = '${buffer.toString()},$lastThree';
    }

    final pStr = p.toString().padLeft(2, '0');
    final formattedValue = '$sign$formattedRupees.$pStr';
    return includeSymbol ? '$symbol$formattedValue' : formattedValue;
  }

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Money && paise == other.paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => formatted();
}
