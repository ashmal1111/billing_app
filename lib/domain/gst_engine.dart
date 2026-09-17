import 'money.dart';

/// Official 2-digit Indian GST State / Union Territory Codes (01 to 38)
class IndianState {
  final String code;
  final String name;
  final bool isUnionTerritory;

  const IndianState({
    required this.code,
    required this.name,
    this.isUnionTerritory = false,
  });

  static const List<IndianState> allStates = [
    IndianState(code: '01', name: 'Jammu and Kashmir', isUnionTerritory: true),
    IndianState(code: '02', name: 'Himachal Pradesh'),
    IndianState(code: '03', name: 'Punjab'),
    IndianState(code: '04', name: 'Chandigarh', isUnionTerritory: true),
    IndianState(code: '05', name: 'Uttarakhand'),
    IndianState(code: '06', name: 'Haryana'),
    IndianState(code: '07', name: 'Delhi', isUnionTerritory: true),
    IndianState(code: '08', name: 'Rajasthan'),
    IndianState(code: '09', name: 'Uttar Pradesh'),
    IndianState(code: '10', name: 'Bihar'),
    IndianState(code: '11', name: 'Sikkim'),
    IndianState(code: '12', name: 'Arunachal Pradesh'),
    IndianState(code: '13', name: 'Nagaland'),
    IndianState(code: '14', name: 'Manipur'),
    IndianState(code: '15', name: 'Mizoram'),
    IndianState(code: '16', name: 'Tripura'),
    IndianState(code: '17', name: 'Meghalaya'),
    IndianState(code: '18', name: 'Assam'),
    IndianState(code: '19', name: 'West Bengal'),
    IndianState(code: '20', name: 'Jharkhand'),
    IndianState(code: '21', name: 'Odisha'),
    IndianState(code: '22', name: 'Chhattisgarh'),
    IndianState(code: '23', name: 'Madhya Pradesh'),
    IndianState(code: '24', name: 'Gujarat'),
    IndianState(
        code: '26',
        name: 'Dadra and Nagar Haveli and Daman and Diu',
        isUnionTerritory: true),
    IndianState(code: '27', name: 'Maharashtra'),
    IndianState(code: '28', name: 'Andhra Pradesh (Old)'),
    IndianState(code: '29', name: 'Karnataka'),
    IndianState(code: '30', name: 'Goa'),
    IndianState(code: '31', name: 'Lakshadweep', isUnionTerritory: true),
    IndianState(code: '32', name: 'Kerala'),
    IndianState(code: '33', name: 'Tamil Nadu'),
    IndianState(code: '34', name: 'Puducherry', isUnionTerritory: true),
    IndianState(
        code: '35',
        name: 'Andaman and Nicobar Islands',
        isUnionTerritory: true),
    IndianState(code: '36', name: 'Telangana'),
    IndianState(code: '37', name: 'Andhra Pradesh'),
    IndianState(code: '38', name: 'Ladakh', isUnionTerritory: true),
  ];

  static IndianState findByCode(String code) {
    final cleanCode = code.trim().padLeft(2, '0');
    return allStates.firstWhere(
      (s) => s.code == cleanCode,
      orElse: () => const IndianState(code: '32', name: 'Kerala'),
    );
  }

  static IndianState findByName(String name) {
    final clean = name.trim().toLowerCase();
    return allStates.firstWhere(
      (s) => s.name.toLowerCase() == clean,
      orElse: () => const IndianState(code: '32', name: 'Kerala'),
    );
  }
}

/// Breakdown of statutory Indian GST taxes for an item or invoice
class GstTaxBreakdown {
  final Money taxableAmount;
  final double gstRate; // e.g., 18.0
  final bool isInterState;
  final bool isReverseCharge;

  final Money cgst;
  final Money sgst;
  final Money igst;
  final Money cess;

  const GstTaxBreakdown({
    required this.taxableAmount,
    required this.gstRate,
    required this.isInterState,
    this.isReverseCharge = false,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.cess,
  });

  Money get totalTax => isReverseCharge ? Money.zero : (cgst + sgst + igst + cess);
  Money get grandTotal => taxableAmount + totalTax;

  Map<String, dynamic> toJson() => {
        'taxableAmount': taxableAmount.inRupees,
        'gstRate': gstRate,
        'isInterState': isInterState,
        'isReverseCharge': isReverseCharge,
        'cgst': cgst.inRupees,
        'sgst': sgst.inRupees,
        'igst': igst.inRupees,
        'cess': cess.inRupees,
        'totalTax': totalTax.inRupees,
        'grandTotal': grandTotal.inRupees,
      };
}

/// Statutory Indian GST Calculation Engine
class GstEngine {
  /// Standard Indian GST Rates
  static const List<double> standardRates = [0.0, 5.0, 12.0, 18.0, 28.0];

  /// Extract 2-digit state code from a 15-character GSTIN (first 2 digits)
  static String? extractStateCodeFromGstin(String? gstin) {
    if (gstin == null) return null;
    final clean = gstin.trim().toUpperCase();
    if (clean.length >= 2 && RegExp(r'^\d{2}').hasMatch(clean)) {
      return clean.substring(0, 2);
    }
    return null;
  }

  /// Determine if supply is Inter-State (IGST) or Intra-State (CGST + SGST)
  static bool isInterStateSupply({
    required String sellerStateCode,
    required String placeOfSupplyCode,
  }) {
    final s = sellerStateCode.trim().padLeft(2, '0');
    final p = placeOfSupplyCode.trim().padLeft(2, '0');
    return s != p;
  }

  /// Calculate GST from a Tax-Exclusive base amount
  static GstTaxBreakdown calculateFromTaxExclusive({
    required Money taxableAmount,
    required double gstRate,
    required bool isInterState,
    double cessRate = 0.0,
    bool isReverseCharge = false,
  }) {
    if (taxableAmount.isZero || gstRate <= 0) {
      return GstTaxBreakdown(
        taxableAmount: taxableAmount,
        gstRate: gstRate,
        isInterState: isInterState,
        isReverseCharge: isReverseCharge,
        cgst: Money.zero,
        sgst: Money.zero,
        igst: Money.zero,
        cess: Money.zero,
      );
    }

    final Money cess = cessRate > 0 ? taxableAmount.percentage(cessRate) : Money.zero;

    if (isInterState) {
      // Inter-state supply attracts 100% IGST
      final igst = taxableAmount.percentage(gstRate);
      return GstTaxBreakdown(
        taxableAmount: taxableAmount,
        gstRate: gstRate,
        isInterState: true,
        isReverseCharge: isReverseCharge,
        cgst: Money.zero,
        sgst: Money.zero,
        igst: igst,
        cess: cess,
      );
    } else {
      // Intra-state supply splits 50/50 into CGST and SGST
      final halfRate = gstRate / 2.0;
      final cgst = taxableAmount.percentage(halfRate);
      final sgst = taxableAmount.percentage(halfRate);
      return GstTaxBreakdown(
        taxableAmount: taxableAmount,
        gstRate: gstRate,
        isInterState: false,
        isReverseCharge: isReverseCharge,
        cgst: cgst,
        sgst: sgst,
        igst: Money.zero,
        cess: cess,
      );
    }
  }

  /// Decompose a Tax-Inclusive price into base Taxable Amount and GST taxes
  /// Formula: Taxable = Gross / (1 + (Rate / 100))
  static GstTaxBreakdown calculateFromTaxInclusive({
    required Money grossAmount,
    required double gstRate,
    required bool isInterState,
    double cessRate = 0.0,
    bool isReverseCharge = false,
  }) {
    if (grossAmount.isZero || gstRate <= 0) {
      return GstTaxBreakdown(
        taxableAmount: grossAmount,
        gstRate: gstRate,
        isInterState: isInterState,
        isReverseCharge: isReverseCharge,
        cgst: Money.zero,
        sgst: Money.zero,
        igst: Money.zero,
        cess: Money.zero,
      );
    }

    final totalRate = gstRate + cessRate;
    final factor = 1.0 + (totalRate / 100.0);
    final taxablePaise = (grossAmount.paise / factor).round();
    final taxableAmount = Money.fromPaise(taxablePaise);

    return calculateFromTaxExclusive(
      taxableAmount: taxableAmount,
      gstRate: gstRate,
      isInterState: isInterState,
      cessRate: cessRate,
      isReverseCharge: isReverseCharge,
    );
  }
}
