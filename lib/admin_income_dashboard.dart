import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'login_dialog.dart';
import 'supabase_service.dart';

class AdminIncomeDashboard extends StatefulWidget {
  final List<Map<String, dynamic>> invoices;
  final String currency;
  final VoidCallback onRefresh;

  const AdminIncomeDashboard({
    super.key,
    required this.invoices,
    required this.currency,
    required this.onRefresh,
  });

  @override
  State<AdminIncomeDashboard> createState() => _AdminIncomeDashboardState();
}

class _AdminIncomeDashboardState extends State<AdminIncomeDashboard> {
  String _selectedPeriod = 'all'; // 'all', 'this_month', 'last_30_days'

  List<Map<String, dynamic>> get _filteredInvoices {
    if (_selectedPeriod == 'all') return widget.invoices;

    final now = DateTime.now();
    return widget.invoices.where((inv) {
      final dateStr = inv['date']?.toString() ?? '';
      try {
        DateTime? invDate;
        if (dateStr.contains('/')) {
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            invDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } else {
          invDate = DateTime.tryParse(dateStr);
        }

        if (invDate == null) return true;

        if (_selectedPeriod == 'this_month') {
          return invDate.year == now.year && invDate.month == now.month;
        } else if (_selectedPeriod == 'last_30_days') {
          return now.difference(invDate).inDays <= 30;
        }
      } catch (_) {
        return true;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = SupabaseService.instance;
    final isAdmin = auth.isAdmin;

    if (!isAdmin) {
      return _buildAccessDeniedView(context);
    }

    return _buildIncomeDashboardContent(context);
  }

  Widget _buildAccessDeniedView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Income Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.lock, size: 48, color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Admin Privileges Required',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The Income & Revenue Analytics Dashboard contains confidential financial records and is restricted to Administrators.\n\nYou are currently logged in as Staff (${SupabaseService.instance.currentSession?.email ?? "staff"}).',
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        LoginDialog.show(context, onSessionChanged: () {
                          setState(() {});
                          widget.onRefresh();
                        });
                      },
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Log in as Administrator'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeDashboardContent(BuildContext context) {
    final invoices = _filteredInvoices;

    // Financial Metrics Calculation
    double totalGross = 0.0;
    double totalPaid = 0.0;
    double totalPending = 0.0;
    double totalOverdue = 0.0;
    double totalTaxCollected = 0.0;
    double totalDiscounts = 0.0;

    int paidCount = 0;
    int pendingCount = 0;
    int overdueCount = 0;

    final Map<String, double> paymentMethodIncome = {
      'UPI': 0.0,
      'Bank Transfer': 0.0,
      'Cash': 0.0,
      'Card': 0.0,
    };

    final Map<String, Map<String, dynamic>> clientRevenue = {};

    for (final inv in invoices) {
      final double total = (inv['total'] as num?)?.toDouble() ?? 0.0;
      final double tax = (inv['taxAmount'] as num?)?.toDouble() ?? 0.0;
      final double disc = (inv['discountAmount'] as num?)?.toDouble() ?? 0.0;
      final String status =
          (inv['status'] as String? ?? 'pending').toLowerCase();
      final String method = inv['paymentMethod'] as String? ?? 'UPI';
      final String client = inv['clientName'] as String? ?? 'Unknown';

      totalGross += total;
      totalDiscounts += disc;

      if (status == 'paid') {
        totalPaid += total;
        totalTaxCollected += tax;
        paidCount++;
        paymentMethodIncome[method] =
            (paymentMethodIncome[method] ?? 0.0) + total;
      } else if (status == 'overdue') {
        totalOverdue += total;
        overdueCount++;
      } else {
        totalPending += total;
        pendingCount++;
      }

      // Aggregate client revenue
      if (!clientRevenue.containsKey(client)) {
        clientRevenue[client] = {'total': 0.0, 'paid': 0.0, 'count': 0};
      }
      clientRevenue[client]!['total'] =
          (clientRevenue[client]!['total'] as double) + total;
      if (status == 'paid') {
        clientRevenue[client]!['paid'] =
            (clientRevenue[client]!['paid'] as double) + total;
      }
      clientRevenue[client]!['count'] =
          (clientRevenue[client]!['count'] as int) + 1;
    }

    final double collectionRate =
        totalGross > 0 ? (totalPaid / totalGross) * 100 : 0.0;
    final double avgInvoiceValue =
        invoices.isNotEmpty ? totalGross / invoices.length : 0.0;

    // Sort Top Clients
    final sortedClients = clientRevenue.entries.toList()
      ..sort((a, b) =>
          (b.value['total'] as double).compareTo(a.value['total'] as double));

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.query_stats, size: 22),
            SizedBox(width: 8),
            Text('Admin Income Dashboard'),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts),
            tooltip: 'Switch User / Logout',
            onPressed: () {
              LoginDialog.show(context, onSessionChanged: () {
                setState(() {});
                widget.onRefresh();
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => widget.onRefresh(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Period Filter Selector Bar
              _buildPeriodSelector(),
              const SizedBox(height: 16),

              // Hero Income Card
              _buildHeroIncomeCard(
                totalPaid: totalPaid,
                totalGross: totalGross,
                totalPending: totalPending,
                collectionRate: collectionRate,
              ),
              const SizedBox(height: 16),

              // Secondary KPI Grid
              _buildKpiGrid(
                avgInvoiceValue: avgInvoiceValue,
                totalTaxCollected: totalTaxCollected,
                totalDiscounts: totalDiscounts,
                invoiceCount: invoices.length,
              ),
              const SizedBox(height: 20),

              // Status Breakdown Progress & Cards
              _buildStatusBreakdown(
                totalPaid: totalPaid,
                totalPending: totalPending,
                totalOverdue: totalOverdue,
                totalGross: totalGross,
                paidCount: paidCount,
                pendingCount: pendingCount,
                overdueCount: overdueCount,
              ),
              const SizedBox(height: 20),

              // Payment Method Breakdown
              _buildPaymentMethodSection(paymentMethodIncome, totalPaid),
              const SizedBox(height: 20),

              // Top Revenue Clients Leaderboard
              _buildTopClientsSection(sortedClients),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 16, color: Colors.indigo),
          const SizedBox(width: 8),
          const Text('Filter Period:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const Spacer(),
          Wrap(
            spacing: 6,
            children: [
              _periodFilterChip('All Time', 'all'),
              _periodFilterChip('This Month', 'this_month'),
              _periodFilterChip('Last 30 Days', 'last_30_days'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodFilterChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      selectedColor: Colors.indigo,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      visualDensity: VisualDensity.compact,
      onSelected: (val) {
        if (val) setState(() => _selectedPeriod = value);
      },
    );
  }

  Widget _buildHeroIncomeCard({
    required double totalPaid,
    required double totalGross,
    required double totalPending,
    required double collectionRate,
  }) {
    final currency = widget.currency;
    return Card(
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet,
                        color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'REALIZED NET INCOME',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${collectionRate.toStringAsFixed(1)}% Collected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '$currency${NumberFormat("#,##,##0.00").format(totalPaid)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Invoiced',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '$currency${NumberFormat("#,##,##0.00").format(totalGross)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Pending Receivables',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '$currency${NumberFormat("#,##,##0.00").format(totalPending)}',
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid({
    required double avgInvoiceValue,
    required double totalTaxCollected,
    required double totalDiscounts,
    required int invoiceCount,
  }) {
    final currency = widget.currency;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: [
            _kpiCard(
              title: 'Avg Invoice Value',
              value: '$currency${avgInvoiceValue.toStringAsFixed(0)}',
              icon: Icons.analytics,
              color: Colors.purple,
            ),
            _kpiCard(
              title: 'Tax Collected',
              value: '$currency${totalTaxCollected.toStringAsFixed(0)}',
              icon: Icons.receipt_long,
              color: Colors.teal,
            ),
            _kpiCard(
              title: 'Discounts Given',
              value: '$currency${totalDiscounts.toStringAsFixed(0)}',
              icon: Icons.discount,
              color: Colors.orange,
            ),
            _kpiCard(
              title: 'Total Invoices',
              value: '$invoiceCount',
              icon: Icons.description,
              color: Colors.indigo,
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBreakdown({
    required double totalPaid,
    required double totalPending,
    required double totalOverdue,
    required double totalGross,
    required int paidCount,
    required int pendingCount,
    required int overdueCount,
  }) {
    final currency = widget.currency;
    final paidRatio = totalGross > 0 ? (totalPaid / totalGross) : 0.0;
    final pendingRatio = totalGross > 0 ? (totalPending / totalGross) : 0.0;
    final overdueRatio = totalGross > 0 ? (totalOverdue / totalGross) : 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart_outline, size: 18, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Revenue Status Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Segmented Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (paidRatio > 0)
                      Expanded(
                        flex: (paidRatio * 1000).toInt(),
                        child: Container(color: const Color(0xFF16A34A)),
                      ),
                    if (pendingRatio > 0)
                      Expanded(
                        flex: (pendingRatio * 1000).toInt(),
                        child: Container(color: const Color(0xFFEA580C)),
                      ),
                    if (overdueRatio > 0)
                      Expanded(
                        flex: (overdueRatio * 1000).toInt(),
                        child: Container(color: const Color(0xFFDC2626)),
                      ),
                    if (totalGross == 0)
                      Expanded(
                        child: Container(color: Colors.grey.shade300),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status Metric Chips
            Row(
              children: [
                Expanded(
                  child: _statusItem(
                    title: 'Paid ($paidCount)',
                    amount: '$currency${totalPaid.toStringAsFixed(0)}',
                    color: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statusItem(
                    title: 'Pending ($pendingCount)',
                    amount: '$currency${totalPending.toStringAsFixed(0)}',
                    color: const Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statusItem(
                    title: 'Overdue ($overdueCount)',
                    amount: '$currency${totalOverdue.toStringAsFixed(0)}',
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusItem({
    required String title,
    required String amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      fontSize: 11, color: color, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection(
    Map<String, double> paymentMethodIncome,
    double totalPaid,
  ) {
    final currency = widget.currency;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.payment, size: 18, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Payment Methods (Realized Income)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...paymentMethodIncome.entries.map((entry) {
              final pct = totalPaid > 0 ? (entry.value / totalPaid) * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalPaid > 0 ? entry.value / totalPaid : 0.0,
                          backgroundColor: Colors.grey.shade200,
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.indigo),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 95,
                      child: Text(
                        '$currency${entry.value.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopClientsSection(
    List<MapEntry<String, Map<String, dynamic>>> sortedClients,
  ) {
    final currency = widget.currency;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.leaderboard, size: 18, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Top Revenue Clients Leaderboard',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sortedClients.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No invoice transactions recorded yet.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
              )
            else
              ...sortedClients.take(5).toList().asMap().entries.map((item) {
                final rank = item.key + 1;
                final entry = item.value;
                final client = entry.key;
                final data = entry.value;
                final total = data['total'] as double;
                final count = data['count'] as int;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? Colors.amber.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: rank == 1
                          ? Colors.amber.shade300
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              rank == 1 ? Colors.amber : Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              client,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '$count invoice${count > 1 ? "s" : ""}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$currency${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
