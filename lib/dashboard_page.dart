import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/daily_ai_summary.dart';
import 'models/user_profile.dart';
import 'services/client_scope_service.dart';
import 'services/daily_ai_summary_service.dart';
import 'work_orders/task_detail_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    this.userProfile,
    required this.canAccessAssets,
    required this.canAccessLocations,
    required this.canAccessWorkOrders,
    required this.canAccessAlerts,
    required this.canAccessSettings,
    required this.canCreateWorkOrders,
    required this.onOpenAssets,
    required this.onOpenLocations,
    required this.onOpenWorkOrders,
    required this.onOpenAlerts,
    required this.onOpenSettings,
    required this.onCreateWorkOrder,
  });

  final UserProfile? userProfile;
  final bool canAccessAssets;
  final bool canAccessLocations;
  final bool canAccessWorkOrders;
  final bool canAccessAlerts;
  final bool canAccessSettings;
  final bool canCreateWorkOrders;
  final VoidCallback onOpenAssets;
  final VoidCallback onOpenLocations;
  final VoidCallback onOpenWorkOrders;
  final VoidCallback onOpenAlerts;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onCreateWorkOrder;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String? errorMessage;
  int assetCount = 0;
  int locationCount = 0;
  int openWorkOrderCount = 0;
  int alertCount = 0;
  List<Map<String, dynamic>> recentOrders = [];
  DailyAiSummary? dailyAiSummary;
  String? dailyAiSummaryErrorMessage;
  bool isGeneratingDailyAiSummary = false;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  bool get canAccessDailyAiSummary => widget.userProfile?.isAdmin == true;

  DateTime get todaySummaryDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<_DashboardDailyAiSummaryLoad> loadTodayAiSummary() async {
    try {
      final summary = await DailyAiSummaryService.instance.fetchSummaryForDate(
        summaryDate: todaySummaryDate,
      );
      return _DashboardDailyAiSummaryLoad(summary: summary);
    } catch (_) {
      return const _DashboardDailyAiSummaryLoad(
        errorMessage: 'Nao foi possivel carregar o resumo do dia.',
      );
    }
  }

  Future<void> openRecentWorkOrder(Map<String, dynamic> order) async {
    final assetId = order['asset_id'];
    Map<String, dynamic> asset = {'id': assetId, 'name': order['asset_name']};

    if (assetId != null) {
      try {
        final assetData = await supabase
            .from('assets')
            .select()
            .eq('id', assetId)
            .maybeSingle();

        if (assetData != null) {
          asset = Map<String, dynamic>.from(assetData);
        }
      } catch (_) {
        // Fall back to the minimal asset payload if the refresh fails.
      }
    }

    if (!mounted) return;

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(
          task: order,
          asset: asset,
          canManageAll: widget.userProfile?.isAdmin == true,
          canEditFullOrder:
              widget.userProfile?.isAdmin == true ||
              widget.userProfile?.canEditWorkOrders == true,
          canCloseWorkOrder:
              widget.userProfile?.isAdmin == true ||
              widget.userProfile?.canCloseWorkOrders != false,
          userProfile: widget.userProfile,
        ),
      ),
    );

    if (changed == true) {
      await loadDashboard();
    }
  }

  Future<void> loadDashboard() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final needsAssetScopeData =
          widget.userProfile?.isClient == true &&
          (widget.canAccessLocations || widget.canAccessWorkOrders);
      final aiSummaryFuture = canAccessDailyAiSummary
          ? loadTodayAiSummary()
          : null;
      final futures = <Future<dynamic>>[
        if (widget.canAccessAssets || needsAssetScopeData)
          supabase.from('assets').select('id, location_id'),
        if (widget.canAccessLocations) supabase.from('locations').select('id'),
        if (widget.canAccessWorkOrders)
          supabase
              .from('work_orders')
              .select('id, status, asset_id, technician_id')
              .neq('status', 'concluido')
              .order('created_at', ascending: false),
        if (widget.canAccessWorkOrders)
          supabase
              .from('work_orders')
              .select(
                'id, title, description, status, created_at, asset_id, technician_id',
              )
              .order('created_at', ascending: false)
              .limit(5),
        if (widget.canAccessAlerts)
          supabase.from('admin_notifications').select('id'),
      ];

      final results = await Future.wait(futures);
      var cursor = 0;

      List<Map<String, dynamic>> assetRows = const [];
      if (widget.canAccessAssets || needsAssetScopeData) {
        assetRows = List<Map<String, dynamic>>.from(results[cursor++] as List);
      }

      List<Map<String, dynamic>> locationRows = const [];
      if (widget.canAccessLocations) {
        locationRows = List<Map<String, dynamic>>.from(
          results[cursor++] as List,
        );
      }

      List<Map<String, dynamic>> openOrders = const [];
      if (widget.canAccessWorkOrders) {
        openOrders = List<Map<String, dynamic>>.from(results[cursor++] as List);
      }

      List<Map<String, dynamic>> latestOrders = const [];
      if (widget.canAccessWorkOrders) {
        latestOrders = List<Map<String, dynamic>>.from(results[cursor++] as List);
      }

      var nextAssetCount = assetCount;
      var nextLocationCount = locationCount;
      var nextOpenWorkOrderCount = openWorkOrderCount;
      var nextAlertCount = alertCount;
      var nextRecentOrders = recentOrders;

      if (widget.canAccessAssets) {
        assetRows = assetRows
            .where(
              (asset) => ClientScopeService.canAccessAsset(
                widget.userProfile,
                asset,
              ),
            )
            .toList();
        nextAssetCount = assetRows.length;
      } else if (needsAssetScopeData) {
        assetRows = assetRows
            .where(
              (asset) => ClientScopeService.canAccessAsset(
                widget.userProfile,
                asset,
              ),
            )
            .toList();
      }

      if (widget.canAccessLocations) {
        locationRows = locationRows
            .where(
              (location) => ClientScopeService.canAccessLocation(
                widget.userProfile,
                location,
                assets: assetRows,
              ),
            )
            .toList();
        nextLocationCount = locationRows.length;
      }

      if (widget.canAccessWorkOrders) {
        final assetMap = {
          for (final asset in assetRows) asset['id']?.toString() ?? '': asset,
        };
        openOrders = openOrders
            .where(
              (order) => ClientScopeService.canAccessWorkOrder(
                widget.userProfile,
                order,
                assetsById: assetMap,
              ),
            )
            .toList();
        latestOrders = latestOrders
            .where(
              (order) => ClientScopeService.canAccessWorkOrder(
                widget.userProfile,
                order,
                assetsById: assetMap,
              ),
            )
            .toList();
        nextOpenWorkOrderCount = openOrders.length;
        nextRecentOrders = latestOrders;
      }

      if (widget.canAccessAlerts) {
        nextAlertCount = List<Map<String, dynamic>>.from(
          results[cursor++] as List,
        ).length;
      }

      final aiSummaryLoad = aiSummaryFuture == null ? null : await aiSummaryFuture;

      if (!mounted) return;
      setState(() {
        assetCount = nextAssetCount;
        locationCount = nextLocationCount;
        openWorkOrderCount = nextOpenWorkOrderCount;
        alertCount = nextAlertCount;
        recentOrders = nextRecentOrders;
        if (canAccessDailyAiSummary) {
          dailyAiSummary = aiSummaryLoad?.summary;
          dailyAiSummaryErrorMessage = aiSummaryLoad?.errorMessage;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Nao foi possivel carregar o resumo.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> generateDailyAiSummary() async {
    if (isGeneratingDailyAiSummary) return;

    setState(() {
      isGeneratingDailyAiSummary = true;
      dailyAiSummaryErrorMessage = null;
    });

    try {
      final result = await DailyAiSummaryService.instance.generateSummary(
        summaryDate: todaySummaryDate,
      );

      if (!mounted) return;
      setState(() {
        dailyAiSummary = result.summary;
      });

      final message = result.infoMessage;
      if (message != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        dailyAiSummaryErrorMessage = error.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dailyAiSummaryErrorMessage!)),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isGeneratingDailyAiSummary = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    return RefreshIndicator(
      onRefresh: loadDashboard,
      child: ListView(
        padding: EdgeInsets.all(_isCompactWidth(context) ? 16 : 24),
        children: [
          _SummaryHeader(
            canCreateWorkOrders: widget.canCreateWorkOrders,
            canAccessSettings: widget.canAccessSettings,
            onCreateWorkOrder: widget.onCreateWorkOrder,
            onOpenSettings: widget.onOpenSettings,
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final cardSpacing = compact ? 12.0 : 16.0;
              final availableWidth = constraints.maxWidth;
              final cardWidth = compact
                  ? (availableWidth - cardSpacing) / 2
                  : 220.0;

              return Wrap(
                spacing: cardSpacing,
                runSpacing: cardSpacing,
                children: [
                  if (widget.canAccessAssets)
                    _SummaryMetricCard(
                      title: 'Ativos',
                      value: assetCount.toString(),
                      icon: Icons.precision_manufacturing,
                      color: const Color(0xFF1D4ED8),
                      width: cardWidth,
                      compact: compact,
                      onTap: widget.onOpenAssets,
                    ),
                  if (widget.canAccessLocations)
                    _SummaryMetricCard(
                      title: 'Localizacoes',
                      value: locationCount.toString(),
                      icon: Icons.place,
                      color: const Color(0xFF0F766E),
                      width: cardWidth,
                      compact: compact,
                      onTap: widget.onOpenLocations,
                    ),
                  if (widget.canAccessWorkOrders)
                    _SummaryMetricCard(
                      title: 'Ordens em aberto',
                      value: openWorkOrderCount.toString(),
                      icon: Icons.assignment,
                      color: const Color(0xFFEA580C),
                      width: cardWidth,
                      compact: compact,
                      onTap: widget.onOpenWorkOrders,
                    ),
                  if (widget.canAccessAlerts)
                    _SummaryMetricCard(
                      title: 'Alertas',
                      value: alertCount.toString(),
                      icon: Icons.notifications_active,
                      color: const Color(0xFFDC2626),
                      width: cardWidth,
                      compact: compact,
                      onTap: widget.onOpenAlerts,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;

              final summaryPanel = _Panel(
                title: 'Resumo Operacional',
                child: Column(
                  children: [
                    if (widget.canAccessAssets)
                      _SummaryLine(
                        label: 'Base de ativos',
                        value: '$assetCount registados',
                        onTap: widget.onOpenAssets,
                      ),
                    if (widget.canAccessLocations)
                      _SummaryLine(
                        label: 'Cobertura de localizacoes',
                        value: '$locationCount registadas',
                        onTap: widget.onOpenLocations,
                      ),
                    if (widget.canAccessWorkOrders)
                      _SummaryLine(
                        label: 'Ordens por tratar',
                        value: '$openWorkOrderCount em aberto',
                        onTap: widget.onOpenWorkOrders,
                      ),
                    if (widget.canAccessAlerts)
                      _SummaryLine(
                        label: 'Alertas pendentes',
                        value: '$alertCount ativos',
                        onTap: widget.onOpenAlerts,
                      ),
                  ],
                ),
              );

              final quickActionsPanel = _Panel(
                title: 'Acessos rapidos',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (widget.canAccessAssets)
                      _ShortcutChip(
                        icon: Icons.precision_manufacturing,
                        label: 'Ativos',
                        onTap: widget.onOpenAssets,
                      ),
                    if (widget.canAccessLocations)
                      _ShortcutChip(
                        icon: Icons.place,
                        label: 'Localizacoes',
                        onTap: widget.onOpenLocations,
                      ),
                    if (widget.canAccessWorkOrders)
                      _ShortcutChip(
                        icon: Icons.assignment,
                        label: 'Ordens',
                        onTap: widget.onOpenWorkOrders,
                      ),
                    if (widget.canAccessAlerts)
                      _ShortcutChip(
                        icon: Icons.notifications,
                        label: 'Alertas',
                        onTap: widget.onOpenAlerts,
                      ),
                    if (widget.canAccessSettings)
                      _ShortcutChip(
                        icon: Icons.settings,
                        label: 'Definicoes',
                        onTap: widget.onOpenSettings,
                      ),
                  ],
                ),
              );

              if (!wide) {
                return Column(
                  children: [
                    summaryPanel,
                    const SizedBox(height: 16),
                    quickActionsPanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: summaryPanel),
                  const SizedBox(width: 16),
                  Expanded(child: quickActionsPanel),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (canAccessDailyAiSummary) ...[
            _DailyAiSummaryPanel(
              summary: dailyAiSummary,
              errorMessage: dailyAiSummaryErrorMessage,
              isGenerating: isGeneratingDailyAiSummary,
              summaryDate: todaySummaryDate,
              onGenerate: generateDailyAiSummary,
            ),
            const SizedBox(height: 18),
          ],
          if (widget.canAccessWorkOrders)
            _Panel(
              title: 'Ultimas ordens',
              child: recentOrders.isEmpty
                  ? const Text('Nao existem ordens registadas neste momento.')
                  : Column(
                      children: recentOrders.map((order) {
                        final title = order['title']?.toString().trim();
                        final description = order['description']
                            ?.toString()
                            .trim();
                        final status =
                            order['status']?.toString() ?? 'pendente';

                        return InkWell(
                          onTap: () => openRecentWorkOrder(order),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withOpacity(0.45),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                      status,
                                    ).withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.assignment_outlined,
                                    color: _statusColor(status),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (title == null || title.isEmpty)
                                            ? 'Ordem sem titulo'
                                            : title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        (description == null ||
                                                description.isEmpty)
                                            ? 'Sem descricao'
                                            : description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Chip(label: Text(status)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'em curso':
        return const Color(0xFFEA580C);
      case 'concluido':
        return const Color(0xFF16A34A);
      case 'pendente':
      default:
        return const Color(0xFF475569);
    }
  }

  bool _isCompactWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 420;
}

class _DashboardDailyAiSummaryLoad {
  const _DashboardDailyAiSummaryLoad({
    this.summary,
    this.errorMessage,
  });

  final DailyAiSummary? summary;
  final String? errorMessage;
}

class _DailyAiSummaryPanel extends StatelessWidget {
  const _DailyAiSummaryPanel({
    required this.summary,
    required this.errorMessage,
    required this.isGenerating,
    required this.summaryDate,
    required this.onGenerate,
  });

  final DailyAiSummary? summary;
  final String? errorMessage;
  final bool isGenerating;
  final DateTime summaryDate;
  final Future<void> Function() onGenerate;

  @override
  Widget build(BuildContext context) {
    final effectiveSummary = summary;
    final hasSummary = effectiveSummary != null && effectiveSummary.isReady;
    final buttonLabel = isGenerating
        ? 'A gerar...'
        : hasSummary
        ? 'Atualizar resumo'
        : 'Gerar resumo do dia';

    return _Panel(
      title: 'Resumo do dia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _formatDateLabel(summaryDate),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              FilledButton.icon(
                onPressed: isGenerating
                    ? null
                    : () {
                        onGenerate();
                      },
                icon: Icon(
                  isGenerating ? Icons.hourglass_top : Icons.auto_awesome,
                ),
                label: Text(buttonLabel),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (errorMessage != null) ...[
            _SummaryNotice(
              message: errorMessage!,
              color: const Color(0xFFB91C1C),
              backgroundColor: const Color(0xFFFEE2E2),
            ),
            const SizedBox(height: 14),
          ],
          if (effectiveSummary == null)
            const Text(
              'Ainda nao existe nenhum resumo guardado para hoje. Gera-o manualmente a partir daqui.',
            )
          else if (!effectiveSummary.isReady)
            _SummaryNotice(
              message:
                  effectiveSummary.errorMessage ??
                  'A ultima geracao falhou. Volta a tentar.',
              color: const Color(0xFFB91C1C),
              backgroundColor: const Color(0xFFFEE2E2),
            )
          else ...[
            Text(
              effectiveSummary.headline,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _DailyAiMetaChip(
                  label: effectiveSummary.generationModeLabel,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  textColor: Theme.of(context).colorScheme.onSurface,
                ),
                if (effectiveSummary.generatedAt != null)
                  _DailyAiMetaChip(
                    label:
                        'Gerado ${_formatDateTimeLabel(effectiveSummary.generatedAt!)}',
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    textColor: Theme.of(context).colorScheme.onSurface,
                  ),
                if (effectiveSummary.model != null)
                  _DailyAiMetaChip(
                    label: effectiveSummary.model!,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    textColor: Theme.of(context).colorScheme.onSurface,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DailyAiStatChip(
                  label: 'Planeado',
                  value: effectiveSummary.sourceStats.plannedAssetsCount,
                ),
                _DailyAiStatChip(
                  label: 'Com atividade',
                  value: effectiveSummary.sourceStats.touchedOrdersCount,
                ),
                _DailyAiStatChip(
                  label: 'Concluidas',
                  value: effectiveSummary.sourceStats.completedOrdersCount,
                ),
                _DailyAiStatChip(
                  label: 'Em aberto',
                  value: effectiveSummary.sourceStats.openOrdersCount,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DailyAiSummarySection(
              title: 'Feito hoje',
              items: effectiveSummary.completed,
            ),
            const SizedBox(height: 14),
            _DailyAiSummarySection(
              title: 'Por concluir',
              items: effectiveSummary.unfinished,
            ),
            const SizedBox(height: 14),
            _DailyAiSummarySection(
              title: 'Bloqueios',
              items: effectiveSummary.blocked,
            ),
            const SizedBox(height: 14),
            _DailyAiSummarySection(
              title: 'Atencao para amanha',
              items: effectiveSummary.attentionTomorrow,
            ),
            if (effectiveSummary.note != null) ...[
              const SizedBox(height: 14),
              Text(
                effectiveSummary.note!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SummaryNotice extends StatelessWidget {
  const _SummaryNotice({
    required this.message,
    required this.color,
    required this.backgroundColor,
  });

  final String message;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DailyAiMetaChip extends StatelessWidget {
  const _DailyAiMetaChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DailyAiStatChip extends StatelessWidget {
  const _DailyAiStatChip({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DailyAiSummarySection extends StatelessWidget {
  const _DailyAiSummarySection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'Sem registos relevantes.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Column(
            children: items
                .map((item) => _DailyAiSummaryBullet(text: item))
                .toList(),
          ),
      ],
    );
  }
}

class _DailyAiSummaryBullet extends StatelessWidget {
  const _DailyAiSummaryBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _formatDateLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

String _formatDateTimeLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.canCreateWorkOrders,
    required this.canAccessSettings,
    required this.onCreateWorkOrder,
    required this.onOpenSettings,
  });

  final bool canCreateWorkOrders;
  final bool canAccessSettings;
  final Future<void> Function() onCreateWorkOrder;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 420;

    if (compact) {
      if (!canCreateWorkOrders) {
        return const SizedBox.shrink();
      }

      return FilledButton.icon(
        onPressed: () {
          onCreateWorkOrder();
        },
        icon: const Icon(Icons.add_task),
        label: const Text('Nova ordem'),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visao geral',
              style:
                  (compact
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.headlineSmall)
                      ?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              'Resumo rapido da operacao atual, com indicadores principais e atalhos para as areas mais usadas.',
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
              style:
                  (compact
                          ? Theme.of(context).textTheme.bodySmall
                          : Theme.of(context).textTheme.bodyMedium)
                      ?.copyWith(height: 1.4),
            ),
            SizedBox(height: compact ? 12 : 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (canCreateWorkOrders)
                  FilledButton.icon(
                    onPressed: () {
                      onCreateWorkOrder();
                    },
                    icon: const Icon(Icons.add_task),
                    label: const Text('Nova ordem'),
                  ),
                if (canAccessSettings)
                  OutlinedButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('Abrir definicoes'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
    required this.compact,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.all(compact ? 14 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 36 : 42,
                  height: compact ? 36 : 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: compact ? 18 : 24),
                ),
                SizedBox(height: compact ? 12 : 16),
                Text(
                  value,
                  style:
                      (compact
                              ? Theme.of(context).textTheme.headlineSmall
                              : Theme.of(context).textTheme.headlineMedium)
                          ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (compact
                              ? Theme.of(context).textTheme.bodyMedium
                              : Theme.of(context).textTheme.titleMedium)
                          ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
