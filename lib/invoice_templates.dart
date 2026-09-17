import 'package:flutter/material.dart';

enum InvoiceTemplate {
  modern(
    id: 'modern',
    name: 'Modern Gradient',
    icon: Icons.auto_awesome,
    accentColor: Colors.indigo,
    description: 'Vibrant gradient banner with card-based details',
  ),
  classic(
    id: 'classic',
    name: 'Classic Corporate',
    icon: Icons.business,
    accentColor: Color(0xFF1E3A8A),
    description: 'Traditional formal grid with corporate signatory',
  ),
  minimal(
    id: 'minimal',
    name: 'Minimal Clean',
    icon: Icons.crop_landscape,
    accentColor: Color(0xFF111827),
    description: 'Sleek monochrome editorial layout with hairline dividers',
  ),
  emerald(
    id: 'emerald',
    name: 'Emerald Creative',
    icon: Icons.palette,
    accentColor: Color(0xFF047857),
    description: 'Fresh emerald accents with dual-column summary',
  ),
  receipt(
    id: 'receipt',
    name: 'Thermal POS Receipt',
    icon: Icons.receipt_long,
    accentColor: Color(0xFF374151),
    description: 'Compact retail POS layout with dashed separators',
  );

  final String id;
  final String name;
  final IconData icon;
  final Color accentColor;
  final String description;

  const InvoiceTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.accentColor,
    required this.description,
  });

  static InvoiceTemplate fromId(String? id) {
    return InvoiceTemplate.values.firstWhere(
      (t) => t.id == id,
      orElse: () => InvoiceTemplate.modern,
    );
  }
}

class InvoiceTemplateView extends StatelessWidget {
  final InvoiceTemplate template;
  final String invoiceNumber;
  final String date;
  final String dueDate;
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final String clientAddress;
  final String clientGst;
  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String companyEmail;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double discountPercent;
  final double discountAmount;
  final double total;
  final String currency;
  final String status;
  final String paymentMethod;
  final String notes;

  const InvoiceTemplateView({
    super.key,
    required this.template,
    required this.invoiceNumber,
    required this.date,
    required this.dueDate,
    required this.clientName,
    required this.clientEmail,
    required this.clientPhone,
    required this.clientAddress,
    required this.clientGst,
    required this.companyName,
    required this.companyAddress,
    required this.companyPhone,
    required this.companyEmail,
    required this.items,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.discountPercent,
    required this.discountAmount,
    required this.total,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    required this.notes,
  });

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color(0xFF16A34A);
      case 'pending':
        return const Color(0xFFEA580C);
      case 'overdue':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (template) {
      case InvoiceTemplate.classic:
        return _buildClassicTemplate(context);
      case InvoiceTemplate.minimal:
        return _buildMinimalTemplate(context);
      case InvoiceTemplate.emerald:
        return _buildEmeraldTemplate(context);
      case InvoiceTemplate.receipt:
        return _buildReceiptTemplate(context);
      case InvoiceTemplate.modern:
        return _buildModernTemplate(context);
    }
  }

  // ==========================================
  // 1. MODERN GRADIENT TEMPLATE
  // ==========================================
  Widget _buildModernTemplate(BuildContext context) {
    return Card(
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo, Colors.indigoAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INVOICE',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        companyName,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      invoiceNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _infoBox(
                        title: 'BILL TO',
                        lines: [
                          clientName.isEmpty ? 'Not specified' : clientName,
                          if (clientEmail.isNotEmpty) clientEmail,
                          if (clientPhone.isNotEmpty) clientPhone,
                          if (clientAddress.isNotEmpty) clientAddress,
                          if (clientGst.isNotEmpty) 'GST: $clientGst',
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _infoBox(
                        title: 'INVOICE DETAILS',
                        lines: [
                          'Date: $date',
                          'Due: $dueDate',
                          'Payment: $paymentMethod',
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildItemsTable(headerBg: Colors.indigo.shade50),
                const SizedBox(height: 16),
                _buildTotalsBox(
                  bg: Colors.indigo.shade50,
                  accentColor: Colors.indigo,
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildNotesBox(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. CLASSIC CORPORATE TEMPLATE
  // ==========================================
  Widget _buildClassicTemplate(BuildContext context) {
    const corporateBlue = Color(0xFF1E3A8A);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: corporateBlue,
                        ),
                      ),
                      if (companyAddress.isNotEmpty)
                        Text(companyAddress,
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 12)),
                      if (companyPhone.isNotEmpty || companyEmail.isNotEmpty)
                        Text('$companyPhone | $companyEmail',
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'TAX INVOICE',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: corporateBlue,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text('Invoice #: $invoiceNumber',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Date: $date',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 12)),
                    Text('Due Date: $dueDate',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const Divider(thickness: 2, color: corporateBlue, height: 32),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BILLED TO:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: corporateBlue)),
                      const SizedBox(height: 4),
                      Text(clientName.isEmpty ? 'Client' : clientName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      if (clientAddress.isNotEmpty)
                        Text(clientAddress,
                            style: const TextStyle(fontSize: 12)),
                      if (clientPhone.isNotEmpty)
                        Text('Ph: $clientPhone',
                            style: const TextStyle(fontSize: 12)),
                      if (clientGst.isNotEmpty)
                        Text('GSTIN: $clientGst',
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: _getStatusColor(), width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildItemsTable(
              headerBg: corporateBlue,
              headerTextColor: Colors.white,
              borderColor: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment Terms: $paymentMethod',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(notes,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade700)),
                      ],
                      const SizedBox(height: 24),
                      Text('Authorized Signature',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Container(
                          width: 140, height: 1, color: Colors.grey.shade400),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _buildTotalsBox(
                    bg: Colors.grey.shade100,
                    accentColor: corporateBlue,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. MINIMAL CLEAN TEMPLATE
  // ==========================================
  Widget _buildMinimalTemplate(BuildContext context) {
    const darkText = Color(0xFF111827);
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Invoice'.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4,
                    color: darkText,
                  ),
                ),
                Text(
                  invoiceNumber,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: darkText),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(height: 1, color: darkText),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FROM',
                          style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(companyName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: darkText)),
                      if (companyEmail.isNotEmpty)
                        Text(companyEmail,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BILLED TO',
                          style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(clientName.isEmpty ? 'Client' : clientName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: darkText)),
                      if (clientPhone.isNotEmpty)
                        Text(clientPhone,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('DATE',
                          style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(date,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: darkText)),
                      Text('Due: $dueDate',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildItemsTable(
              headerBg: Colors.white,
              headerTextColor: darkText,
              borderColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 260,
                child: Column(
                  children: [
                    _subtotalRow(
                        'Subtotal', '$currency${subtotal.toStringAsFixed(2)}'),
                    if (taxRate > 0)
                      _subtotalRow('Tax (${taxRate.toInt()}%)',
                          '$currency${taxAmount.toStringAsFixed(2)}'),
                    if (discountPercent > 0)
                      _subtotalRow('Discount (${discountPercent.toInt()}%)',
                          '-$currency${discountAmount.toStringAsFixed(2)}'),
                    const Divider(height: 20, color: darkText),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: darkText)),
                        Text('$currency${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: darkText)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. EMERALD CREATIVE TEMPLATE
  // ==========================================
  Widget _buildEmeraldTemplate(BuildContext context) {
    const emerald = Color(0xFF047857);
    const emeraldLight = Color(0xFFECFDF5);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: emerald,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.receipt, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          companyName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  invoiceNumber,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: emeraldLight,
                            borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Customer',
                                style: TextStyle(
                                    color: emerald,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(clientName.isEmpty ? 'Client' : clientName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            if (clientEmail.isNotEmpty)
                              Text(clientEmail,
                                  style: const TextStyle(fontSize: 11)),
                            if (clientPhone.isNotEmpty)
                              Text(clientPhone,
                                  style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Summary',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('Date: $date',
                                style: const TextStyle(fontSize: 11)),
                            Text('Due: $dueDate',
                                style: const TextStyle(fontSize: 11)),
                            Text('Payment: $paymentMethod',
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildItemsTable(
                    headerBg: emeraldLight, headerTextColor: emerald),
                const SizedBox(height: 16),
                _buildTotalsBox(bg: emeraldLight, accentColor: emerald),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. THERMAL POS RECEIPT TEMPLATE
  // ==========================================
  Widget _buildReceiptTemplate(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Text(
              companyName.toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
            ),
            if (companyAddress.isNotEmpty)
              Text(companyAddress,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  textAlign: TextAlign.center),
            if (companyPhone.isNotEmpty)
              Text('Tel: $companyPhone',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            _dashedLine(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'RCVD: ${clientName.isEmpty ? "WALK-IN" : clientName}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(date, style: const TextStyle(fontSize: 11)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'INV: $invoiceNumber',
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(paymentMethod.toUpperCase(),
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            _dashedLine(),
            const SizedBox(height: 8),
            ...items.map((item) {
              final lineTotal = item['price'] * item['quantity'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text('${item['name']} x${item['quantity']}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Text('$currency$lineTotal',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            _dashedLine(),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('SUBTOTAL', style: TextStyle(fontSize: 11)),
              Text('$currency${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11)),
            ]),
            if (taxRate > 0)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('TAX (${taxRate.toInt()}%)',
                    style: const TextStyle(fontSize: 11)),
                Text('$currency${taxAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 11)),
              ]),
            if (discountPercent > 0)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('DISC (${discountPercent.toInt()}%)',
                    style: const TextStyle(fontSize: 11)),
                Text('-$currency${discountAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 11)),
              ]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('TOTAL DUE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('$currency${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 8),
            _dashedLine(),
            const SizedBox(height: 8),
            Text(
              '*** THANK YOU FOR YOUR BUSINESS ***',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SHARED REUSABLE COMPONENTS
  // ==========================================
  Widget _dashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.constrainWidth() / 8).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => SizedBox(
                width: 4,
                height: 1,
                child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.grey.shade500))),
          ),
        );
      },
    );
  }

  Widget _infoBox({required String title, required List<String> lines}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.grey)),
          const SizedBox(height: 4),
          ...lines.map((l) => Text(l, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildItemsTable({
    Color? headerBg,
    Color? headerTextColor,
    Color? borderColor,
  }) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text('No items added yet',
            style: TextStyle(color: Colors.grey)),
      );
    }

    final borderC = borderColor ?? Colors.grey.shade300;
    final headerC = headerBg ?? Colors.indigo.shade50;
    final textC = headerTextColor ?? Colors.black87;

    return Table(
      border: TableBorder.all(color: borderC),
      children: [
        TableRow(
          decoration: BoxDecoration(color: headerC),
          children: [
            Padding(
                padding: const EdgeInsets.all(10),
                child: Text('Item',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: textC))),
            Padding(
                padding: const EdgeInsets.all(10),
                child: Text('Qty',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: textC))),
            Padding(
                padding: const EdgeInsets.all(10),
                child: Text('Price',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: textC))),
            Padding(
                padding: const EdgeInsets.all(10),
                child: Text('Total',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: textC))),
          ],
        ),
        ...items.map((item) {
          final lineTotal = item['price'] * item['quantity'];
          return TableRow(
            children: [
              Padding(
                  padding: const EdgeInsets.all(10),
                  child:
                      Text(item['name'], style: const TextStyle(fontSize: 12))),
              Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('${item['quantity']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12))),
              Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('$currency${item['price']}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12))),
              Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('$currency$lineTotal',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTotalsBox({
    required Color bg,
    required Color accentColor,
    BoxBorder? border,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8), border: border),
      child: Column(
        children: [
          _subtotalRow('Subtotal:', '$currency${subtotal.toStringAsFixed(2)}'),
          if (taxRate > 0) ...[
            const SizedBox(height: 6),
            _subtotalRow('GST (${taxRate.toInt()}%):',
                '$currency${taxAmount.toStringAsFixed(2)}'),
          ],
          if (discountPercent > 0) ...[
            const SizedBox(height: 6),
            _subtotalRow('Discount (${discountPercent.toInt()}%):',
                '-$currency${discountAmount.toStringAsFixed(2)}'),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                '$currency${total.toStringAsFixed(2)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: accentColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subtotalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildNotesBox() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notes, size: 16, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Notes: $notes',
              style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
