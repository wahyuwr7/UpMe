import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/settings.dart';
import '../../data/repository.dart';
import '../capture/inbox_screen.dart';
import '../nav.dart';
import '../transactions/txn_editor.dart';
import '../wallet/account_detail.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final settings = context.watch<AppSettings>();
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final sum = repo.summary(month);
    final hour = now.hour;
    final greet = hour < 11 ? 'Good morning' : (hour < 15 ? 'Good afternoon' : (hour < 19 ? 'Good evening' : 'Good night'));

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(greet, style: Theme.of(context).textTheme.labelMedium),
          const Text('UpMe', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(
            tooltip: settings.hideAmounts ? 'Show amounts' : 'Hide amounts',
            icon: Icon(settings.hideAmounts ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => settings.hideAmounts = !settings.hideAmounts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: repo.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (repo.inbox.isNotEmpty) _InboxBanner(count: repo.inbox.length),
            const _NetWorthCard(),
            _MonthCard(month: month, summary: sum),
            if (sum.byCategory.isNotEmpty) _CategoryCard(summary: sum),
            const _AccountsStrip(),
            _TrendCard(month: month),
            SectionHeader('Recent', action: 'See all', onAction: () => homeTab.value = 1),
            if (repo.transactions.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No transactions yet',
                subtitle: 'Tap "Add" or turn on Auto-capture in Settings and let your bank notifications do the work.',
              )
            else
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  for (final t in repo.transactions.take(6))
                    TxnTile(txn: t, showDate: true, onTap: () => showTxnSheet(context, existing: t)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _InboxBanner extends StatelessWidget {
  const _InboxBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      color: cs.primaryContainer,
      child: ListTile(
        leading: Icon(Icons.auto_awesome, color: cs.onPrimaryContainer),
        title: Text('$count detected transaction${count == 1 ? '' : 's'} to confirm',
            style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.chevron_right, color: cs.onPrimaryContainer),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen())),
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final cs = Theme.of(context).colorScheme;
    const onCard = Colors.white;
    Widget item(String label, double v, IconData icon) => Expanded(
          child: Row(children: [
            Icon(icon, size: 16, color: onCard.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: onCard.withValues(alpha: 0.8), fontSize: 11)),
                MoneyText(v, compact: true, style: const TextStyle(color: onCard, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [const Color(0xFF0B7A5F), Color.lerp(const Color(0xFF0B7A5F), cs.tertiary, 0.6)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Net worth', style: TextStyle(color: onCard.withValues(alpha: 0.85))),
        const SizedBox(height: 4),
        MoneyText(repo.netWorth,
            style: const TextStyle(color: onCard, fontSize: 32, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Row(children: [
          item('Cash & bank', repo.cashTotal, Icons.account_balance_outlined),
          item('Investments', repo.investmentValue, Icons.trending_up),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          item('Cards owed', -repo.creditCardOutstanding, Icons.credit_card),
          item('Debts (net)', repo.owedToMe - repo.iOwe, Icons.handshake_outlined),
        ]),
      ]),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.month, required this.summary});
  final DateTime month;
  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final daily = repo.dailyExpense(month);
    final today = DateTime.now().day;
    final maxY = daily.fold<double>(0, math.max);
    final avg = today == 0 ? 0.0 : summary.expense / today;
    final cs = Theme.of(context).colorScheme;

    Widget stat(String label, double v, Color c) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: MoneyText(v, compact: true, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            ]),
          ]),
        );

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(DateFormat('MMMM').format(month), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(children: [
          stat('Income', summary.income, incomeColor),
          stat('Spent', summary.expense, expenseColor),
          stat('Left', summary.net, summary.net >= 0 ? incomeColor : expenseColor),
        ]),
        const SizedBox(height: 16),
        Text('Daily spending · avg ${Money.format(avg, compact: true)}/day',
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: BarChart(BarChartData(
            maxY: maxY == 0 ? 1 : maxY * 1.1,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => cs.inverseSurface,
                getTooltipItem: (g, _, r, _) => BarTooltipItem(
                  '${DateFormat('d MMM').format(DateTime(month.year, month.month, g.x + 1))}\n${Money.format(r.toY)}',
                  TextStyle(color: cs.onInverseSurface, fontSize: 12),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < daily.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: daily[i],
                    width: 5,
                    color: i + 1 == today ? expenseColor : expenseColor.withValues(alpha: i + 1 > today ? 0.15 : 0.55),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]),
            ],
          )),
        ),
      ]),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.summary});
  final MonthSummary summary;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final entries = widget.summary.byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    // Fold the long tail into "Other" so the donut stays readable.
    final top = entries.take(5).toList();
    final rest = entries.skip(5).fold<double>(0, (s, e) => s + e.value);
    final total = widget.summary.expense;
    final slices = <({String name, double value, Color color, IconData icon})>[
      for (final e in top)
        (
          name: repo.category(e.key)?.name ?? 'Uncategorized',
          value: e.value,
          color: Color(repo.category(e.key)?.color ?? 0xFF9E9E9E),
          icon: repo.category(e.key)?.iconData ?? Icons.help_outline,
        ),
      if (rest > 0) (name: 'Everything else', value: rest, color: const Color(0xFFB0BEC5), icon: Icons.more_horiz),
    ];
    final surface = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Where the money went', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(
            width: 130,
            height: 130,
            child: Stack(alignment: Alignment.center, children: [
              PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 42,
                pieTouchData: PieTouchData(touchCallback: (e, r) {
                  setState(() => _touched =
                      (e.isInterestedForInteractions ? r?.touchedSection?.touchedSectionIndex : null));
                }),
                sections: [
                  for (var i = 0; i < slices.length; i++)
                    PieChartSectionData(
                      value: slices[i].value,
                      color: slices[i].color,
                      radius: _touched == i ? 22 : 18,
                      showTitle: false,
                      borderSide: BorderSide(color: surface, width: 0),
                    ),
                ],
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_touched != null && _touched! < slices.length ? slices[_touched!].name : 'Spent',
                    style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(
                  width: 80,
                  child: FittedBox(
                    child: MoneyText(
                      _touched != null && _touched! < slices.length ? slices[_touched!].value : total,
                      compact: true,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(children: [
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                    Text('${(s.value / total * 100).round()}%', style: Theme.of(context).textTheme.labelMedium),
                  ]),
                ),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _AccountsStrip extends StatelessWidget {
  const _AccountsStrip();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final accounts = repo.activeAccounts;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Accounts'),
      SizedBox(
        height: 108,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: accounts.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (c, i) {
            final a = accounts[i];
            final bal = repo.balanceOf(a.id!);
            return SizedBox(
              width: 156,
              child: Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AccountDetailScreen(accountId: a.id!))),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(a.type.icon, color: Color(a.color), size: 20),
                        const SizedBox(width: 6),
                        Expanded(child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                      const Spacer(),
                      Text(a.isCreditCard ? 'Outstanding' : 'Balance', style: Theme.of(c).textTheme.labelSmall),
                      MoneyText(a.isCreditCard ? -bal : bal,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: a.isCreditCard && bal < 0 ? expenseColor : null)),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FinanceRepository>();
    final cs = Theme.of(context).colorScheme;
    final months = [for (var i = 5; i >= 0; i--) DateTime(month.year, month.month - i)];
    final sums = months.map(repo.summary).toList();
    final maxY = sums.fold<double>(0, (m, s) => math.max(m, math.max(s.income, s.expense)));
    if (maxY == 0) return const SizedBox.shrink();

    Widget legend(String label, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ]);

    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Last 6 months', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          legend('Income', incomeColor),
          const SizedBox(width: 10),
          legend('Spent', expenseColor),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: BarChart(BarChartData(
            maxY: maxY * 1.15,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY / 3,
              getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: maxY / 3,
                  getTitlesWidget: (v, meta) => v == meta.max
                      ? const SizedBox.shrink()
                      : Text(NumberFormat.compact().format(v), style: Theme.of(context).textTheme.labelSmall),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(DateFormat('MMM').format(months[v.toInt()]), style: Theme.of(context).textTheme.labelSmall),
                  ),
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => cs.inverseSurface,
                getTooltipItem: (g, _, r, i) => BarTooltipItem(
                  '${i == 0 ? 'Income' : 'Spent'} ${DateFormat('MMM').format(months[g.x])}\n${Money.format(r.toY)}',
                  TextStyle(color: cs.onInverseSurface, fontSize: 12),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < sums.length; i++)
                BarChartGroupData(x: i, barsSpace: 2, barRods: [
                  BarChartRodData(toY: sums[i].income, width: 10, color: incomeColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                  BarChartRodData(toY: sums[i].expense, width: 10, color: expenseColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                ]),
            ],
          )),
        ),
      ]),
    );
  }
}
