import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/plan_model.dart';
import '../viewmodel/plan_detail_viewmodel.dart';
import 'widgets/checklist_card.dart';

class PlanDetailPage extends ConsumerStatefulWidget {
  final String planId;
  const PlanDetailPage({super.key, required this.planId});

  @override
  ConsumerState<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends ConsumerState<PlanDetailPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(planDetailProvider(widget.planId));
    return state.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.paper,
        body: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.paper,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.coral, size: 48),
              const SizedBox(height: 12),
              Text('获取失败', style: GoogleFonts.dmSans(fontSize: 16)),
              TextButton(
                onPressed: () => ref.read(planDetailProvider(widget.planId).notifier).refresh(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      data: (plan) => _buildPage(plan),
    );
  }

  Widget _buildPage(TravelPlan? plan) {
    if (plan == null) {
      return const Scaffold(
        backgroundColor: AppColors.paper,
        body: Center(child: Text('行程不存在')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        title: Text(plan.title, style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: () => _editTitle(plan), icon: const Icon(Icons.edit_outlined)),
          IconButton(onPressed: () => _showExport(plan), icon: const Icon(Icons.ios_share_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _HeroCard(plan: plan, onEdit: () => _editSummary(plan)),
          const SizedBox(height: 12),
          ChecklistCard(
            checklist: plan.checklistData,
            onToggle: (index) => ref.read(planDetailProvider(widget.planId).notifier).toggleChecklist(index),
          ),
          _card(
            '行前准备',
            action: '编辑',
            onAction: () => _editPreparation(plan),
            child: _kvList([
              ['最佳季节', plan.guideData.preparation.bestSeason ?? '未填写'],
              ['往返交通', _join(plan.guideData.preparation.longDistanceTransport)],
              ['市内交通', _join(plan.guideData.preparation.cityTransport)],
              ['携带清单', _join(plan.guideData.preparation.packingList)],
              ['证件提醒', _join(plan.guideData.preparation.documents)],
            ]),
          ),
          _card(
            '预算表',
            action: '编辑',
            onAction: () => _editBudget(plan),
            child: plan.guideData.budget.isEmpty
                ? _muted('还没有预算表，点击右上角补充。')
                : Table(
                    border: TableBorder.all(color: AppColors.rule, borderRadius: BorderRadius.circular(12)),
                    children: [
                      const TableRow(children: [
                        _TableHead('类别'),
                        _TableHead('预算区间'),
                      ]),
                      ...plan.guideData.budget.map((item) => TableRow(children: [
                            _TableCell(text: item.category),
                            _TableCell(text: item.amountRange),
                          ])),
                    ],
                  ),
          ),
          _card(
            '住宿建议',
            action: '编辑',
            onAction: () => _editAccommodation(plan),
            child: plan.guideData.accommodation.isEmpty
                ? _muted('还没有住宿建议。')
                : Column(
                    children: plan.guideData.accommodation.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.rule),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.tier}｜${item.name}', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.ink)),
                            if ((item.priceRange ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(item.priceRange!, style: GoogleFonts.dmSans(color: AppColors.tealDeep)),
                            ],
                            if (item.highlights.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: item.highlights.map((tag) => _chip(tag)).toList(),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          _sectionTitle('每日行程'),
          ...plan.itineraryData.map((day) => _dayCard(plan, day)),
          _card(
            '避坑提醒',
            action: '编辑',
            onAction: () => _editAvoidTips(plan),
            child: plan.guideData.avoidTips.isEmpty
                ? _muted('还没有避坑提醒。')
                : Column(
                    children: plan.guideData.avoidTips.map((tip) => _tipBox(tip)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _editTitle(TravelPlan plan) async {
    final c = TextEditingController(text: plan.title);
    final ok = await _dialog('修改标题', TextField(controller: c, decoration: const InputDecoration(labelText: '标题')));
    if (ok == true) await _save(plan.copyWith(title: c.text.trim()), '标题已更新');
  }

  Future<void> _editSummary(TravelPlan plan) async {
    final summary = TextEditingController(text: plan.guideData.summary ?? '');
    final tags = TextEditingController(text: plan.guideData.styleTags.join('\n'));
    final notes = TextEditingController(text: plan.guideData.notes.join('\n'));
    final ok = await _dialog(
      '编辑摘要',
      Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: summary, minLines: 4, maxLines: 6, decoration: const InputDecoration(labelText: '摘要')),
        const SizedBox(height: 10),
        TextField(controller: tags, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: '风格标签，每行一个')),
        const SizedBox(height: 10),
        TextField(controller: notes, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: '备注，每行一个')),
      ]),
    );
    if (ok == true) {
      await _save(
        plan.copyWith(
          guideData: plan.guideData.copyWith(
            summary: summary.text.trim(),
            styleTags: _lines(tags.text),
            notes: _lines(notes.text),
          ),
        ),
        '摘要已更新',
      );
    }
  }

  Future<void> _editPreparation(TravelPlan plan) async {
    final prep = plan.guideData.preparation;
    final season = TextEditingController(text: prep.bestSeason ?? '');
    final transport = TextEditingController(text: prep.longDistanceTransport.join('\n'));
    final city = TextEditingController(text: prep.cityTransport.join('\n'));
    final packing = TextEditingController(text: prep.packingList.join('\n'));
    final docs = TextEditingController(text: prep.documents.join('\n'));
    final ok = await _dialog('编辑行前准备', Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: season, decoration: const InputDecoration(labelText: '最佳季节')),
      const SizedBox(height: 10),
      TextField(controller: transport, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '往返交通，每行一条')),
      const SizedBox(height: 10),
      TextField(controller: city, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '市内交通，每行一条')),
      const SizedBox(height: 10),
      TextField(controller: packing, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '携带清单，每行一条')),
      const SizedBox(height: 10),
      TextField(controller: docs, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '证件提醒，每行一条')),
    ]));
    if (ok == true) {
      await _save(
        plan.copyWith(
          guideData: plan.guideData.copyWith(
            preparation: prep.copyWith(
              bestSeason: season.text.trim(),
              longDistanceTransport: _lines(transport.text),
              cityTransport: _lines(city.text),
              packingList: _lines(packing.text),
              documents: _lines(docs.text),
            ),
          ),
        ),
        '行前准备已更新',
      );
    }
  }

  Future<void> _editBudget(TravelPlan plan) async {
    final c = TextEditingController(text: plan.guideData.budget.map((e) => '${e.category}|${e.amountRange}').join('\n'));
    final ok = await _dialog('编辑预算表', TextField(controller: c, minLines: 6, maxLines: 10, decoration: const InputDecoration(labelText: '格式：类别|预算区间')));
    if (ok == true) await _save(plan.copyWith(guideData: plan.guideData.copyWith(budget: _budget(c.text))), '预算表已更新');
  }

  Future<void> _editAccommodation(TravelPlan plan) async {
    final c = TextEditingController(text: plan.guideData.accommodation.map((e) => '${e.tier}|${e.name}|${e.priceRange ?? ''}|${e.highlights.join(',')}').join('\n'));
    final ok = await _dialog('编辑住宿建议', TextField(controller: c, minLines: 6, maxLines: 10, decoration: const InputDecoration(labelText: '格式：档位|名称|价格|亮点1,亮点2')));
    if (ok == true) await _save(plan.copyWith(guideData: plan.guideData.copyWith(accommodation: _accommodation(c.text))), '住宿建议已更新');
  }

  Future<void> _editDay(TravelPlan plan, RouteDay day) async {
    final theme = TextEditingController(text: day.theme);
    final summary = TextEditingController(text: day.summary ?? '');
    final stops = TextEditingController(text: day.stops.map((e) => '${e.time}|${e.poiName}|${e.activity}|${e.duration ?? ''}|${e.tips ?? ''}|${e.transportToNext ?? ''}').join('\n'));
    final ok = await _dialog('编辑 Day ${day.day}', Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: theme, decoration: const InputDecoration(labelText: '主题')),
      const SizedBox(height: 10),
      TextField(controller: summary, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '摘要')),
      const SizedBox(height: 10),
      TextField(controller: stops, minLines: 8, maxLines: 14, decoration: const InputDecoration(labelText: '格式：时间|地点|安排|时长|提示|到下一站交通')),
    ]));
    if (ok == true) {
      final days = plan.itineraryData.map((item) => item.day == day.day ? item.copyWith(theme: theme.text.trim(), summary: summary.text.trim(), stops: _stops(stops.text)) : item).toList();
      await _save(plan.copyWith(itineraryData: days), '每日行程已更新');
    }
  }

  Future<void> _editAvoidTips(TravelPlan plan) async {
    final c = TextEditingController(text: plan.guideData.avoidTips.join('\n'));
    final ok = await _dialog('编辑避坑提醒', TextField(controller: c, minLines: 5, maxLines: 8, decoration: const InputDecoration(labelText: '每行一条提醒')));
    if (ok == true) await _save(plan.copyWith(guideData: plan.guideData.copyWith(avoidTips: _lines(c.text))), '避坑提醒已更新');
  }

  Future<void> _showExport(TravelPlan plan) async {
    final markdown = _markdown(plan);
    final csv = _csv(plan);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      builder: (context) => DefaultTabController(
        length: 2,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .78,
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.inkFaint, borderRadius: BorderRadius.circular(999))),
            ListTile(
              title: Text('导出行程', style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.w700)),
              trailing: Wrap(spacing: 6, children: [
                TextButton(onPressed: () => _copy(markdown, 'Markdown'), child: const Text('复制 Markdown')),
                TextButton(onPressed: () => _copy(csv, 'CSV'), child: const Text('复制 CSV')),
              ]),
            ),
            const TabBar(labelColor: AppColors.ink, unselectedLabelColor: AppColors.inkSoft, indicatorColor: AppColors.teal, tabs: [Tab(text: 'Markdown'), Tab(text: 'CSV')]),
            Expanded(child: TabBarView(children: [_preview(markdown), _preview(csv)])),
          ]),
        ),
      ),
    );
  }
  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label 已复制到剪贴板')));
  }

  Future<bool?> _dialog(String title, Widget child) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text(title, style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(child: SizedBox(width: 420, child: child)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), style: FilledButton.styleFrom(backgroundColor: AppColors.ink), child: const Text('保存')),
        ],
      ),
    );
  }

  Future<void> _save(TravelPlan plan, String okMsg) async {
    final ok = await ref.read(planDetailProvider(widget.planId).notifier).savePlan(plan);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? okMsg : '保存失败，请稍后重试')));
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
    child: Text(text, style: GoogleFonts.notoSerifSc(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
  );

  Widget _card(String title, {required Widget child, String? action, VoidCallback? onAction}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.rule)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(title, style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.w700, color: AppColors.ink))), if (action != null && onAction != null) TextButton(onPressed: onAction, child: Text(action))]),
      const SizedBox(height: 12), child,
    ]),
  );

  Widget _dayCard(TravelPlan plan, RouteDay day) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.rule)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(8)), child: Text('Day ${day.day}', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))), const SizedBox(width: 10), Expanded(child: Text(day.theme, style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.w700, color: AppColors.ink))), TextButton(onPressed: () => _editDay(plan, day), child: const Text('编辑'))]),
      if ((day.summary ?? '').isNotEmpty) ...[const SizedBox(height: 8), Text(day.summary!, style: GoogleFonts.dmSans(fontSize: 13, height: 1.6, color: AppColors.inkSoft))],
      const SizedBox(height: 12),
      _ItineraryTable(stops: day.stops),
    ]),
  );

  Widget _kvList(List<List<String>> rows) => Column(children: rows.map((row) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 84, child: Text(row[0], style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink))),
      Expanded(child: Text(row[1], style: GoogleFonts.dmSans(fontSize: 13, height: 1.6, color: AppColors.inkSoft))),
    ]),
  )).toList());

  Widget _muted(String text) => Text(text, style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.inkSoft));
  Widget _chip(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.tealWash, borderRadius: BorderRadius.circular(999)), child: Text(text, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.tealDeep)));
  Widget _tipBox(String text) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.ochreWash, borderRadius: BorderRadius.circular(12)), child: Text(text, style: GoogleFonts.dmSans(fontSize: 13, height: 1.6, color: AppColors.ochre)));
  Widget _preview(String text) => Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.rule)), child: SingleChildScrollView(child: SelectableText(text, style: GoogleFonts.dmSans(fontSize: 12.5, height: 1.6, color: AppColors.inkMid))));

  List<String> _lines(String text) => text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  String _join(List<String> items) => items.isEmpty ? '未填写' : items.join(' / ');
  List<BudgetItem> _budget(String text) => _lines(text).map((line) { final p = line.split('|'); return BudgetItem(category: p.first.trim(), amountRange: p.length > 1 ? p[1].trim() : ''); }).where((e) => e.category.isNotEmpty || e.amountRange.isNotEmpty).toList();
  List<AccommodationSuggestion> _accommodation(String text) => _lines(text).map((line) { final p = line.split('|'); return AccommodationSuggestion(tier: p.isNotEmpty ? p[0].trim() : '', name: p.length > 1 ? p[1].trim() : '', priceRange: p.length > 2 ? p[2].trim() : null, highlights: p.length > 3 ? p[3].split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : const []); }).where((e) => e.name.isNotEmpty).toList();
  List<RouteStop> _stops(String text) => _lines(text).map((line) { final p = line.split('|'); return RouteStop(time: p.isNotEmpty ? p[0].trim() : '', poiName: p.length > 1 ? p[1].trim() : '', activity: p.length > 2 ? p[2].trim() : '', duration: p.length > 3 ? p[3].trim() : null, tips: p.length > 4 ? p[4].trim() : null, transportToNext: p.length > 5 ? p[5].trim() : null); }).where((e) => e.time.isNotEmpty || e.poiName.isNotEmpty || e.activity.isNotEmpty).toList();

  String _markdown(TravelPlan plan) {
    final b = StringBuffer()
      ..writeln('# ${plan.title}')
      ..writeln('- 目的地：${plan.city}')
      ..writeln('- 天数：${plan.days} 天')
      ..writeln('- 场景：${plan.guideData.scene ?? '未填写'}')
      ..writeln()
      ..writeln('## 摘要')
      ..writeln(plan.guideData.summary ?? '未填写')
      ..writeln()
      ..writeln('## 每日行程');
    for (final day in plan.itineraryData) {
      b.writeln('### Day ${day.day}｜${day.theme}');
      if ((day.summary ?? '').isNotEmpty) b.writeln(day.summary!);
      for (final stop in day.stops) { b.writeln('- ${stop.time}｜${stop.poiName}｜${stop.activity}｜${stop.duration ?? ''}'); }
    }
    b..writeln()..writeln('## 待办清单');
    for (final item in plan.checklistData) { b.writeln('- [${item.checked ? 'x' : ' '}] ${item.item}'); }
    return b.toString();
  }

  String _csv(TravelPlan plan) {
    String e(String v) => '"${v.replaceAll('"', '""')}"';
    final rows = <List<String>>[['section','day','time','name','activity','duration','tips','transport']];
    for (final day in plan.itineraryData) {
      for (final stop in day.stops) {
        rows.add(['itinerary','Day ${day.day} ${day.theme}',stop.time,stop.poiName,stop.activity,stop.duration ?? '',stop.tips ?? '',stop.transportToNext ?? '']);
      }
    }
    for (final item in plan.checklistData) { rows.add(['checklist','','',item.item,item.checked ? '已完成' : '待完成','','','']); }
    return rows.map((row) => row.map(e).join(',')).join('\n');
  }
}

class _HeroCard extends StatelessWidget {
  final TravelPlan plan;
  final VoidCallback onEdit;
  const _HeroCard({required this.plan, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final tags = [...plan.guideData.styleTags, if ((plan.guideData.travelType ?? '').isNotEmpty) plan.guideData.travelType!].where((e) => e.trim().isNotEmpty).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.tealDeep, AppColors.teal]), borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('${plan.city} · ${plan.days}天', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))), TextButton(onPressed: onEdit, child: const Text('编辑摘要', style: TextStyle(color: Colors.white)))]),
        Text((plan.guideData.summary ?? '').isEmpty ? '攻略已保存到我的行程，现在可以继续按结构修改和导出。' : plan.guideData.summary!, style: GoogleFonts.dmSans(fontSize: 14, height: 1.7, color: Colors.white.withValues(alpha: .92))),
        if (tags.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: tags.map((tag) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(999)), child: Text(tag, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)))).toList())],
      ]),
    );
  }
}

class _ItineraryTable extends StatelessWidget {
  final List<RouteStop> stops;
  const _ItineraryTable({required this.stops});

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return Text('当天还没有结构化行程。', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.inkSoft));
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.tealWash, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [_HeadFlex('时间',1), _HeadFlex('地点',2), _HeadFlex('安排',3), _HeadFlex('时长',1)]),
      ),
      const SizedBox(height: 8),
      ...stops.map((stop) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.rule)),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _BodyFlex(stop.time,1,bold:true), _BodyFlex(stop.poiName,2,bold:true), _BodyFlex(stop.activity,3), _BodyFlex(stop.duration ?? '-',1),
          ]),
          if ((stop.tips ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.lightbulb_outline_rounded,size:14,color:AppColors.ochre), const SizedBox(width:6), Expanded(child: Text(stop.tips!, style: GoogleFonts.dmSans(fontSize:12, height:1.5, color: AppColors.inkSoft)))])),
          if ((stop.transportToNext ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.route_outlined,size:14,color:AppColors.tealDeep), const SizedBox(width:6), Expanded(child: Text(stop.transportToNext!, style: GoogleFonts.dmSans(fontSize:12, height:1.5, color: AppColors.inkSoft)))])),
        ]),
      )),
    ]);
  }
}

class _HeadFlex extends StatelessWidget { final String text; final int flex; const _HeadFlex(this.text,this.flex); @override Widget build(BuildContext context) => Expanded(flex:flex, child: Text(text, style: GoogleFonts.dmSans(fontSize:12, fontWeight:FontWeight.w700, color: AppColors.tealDeep))); }
class _BodyFlex extends StatelessWidget { final String text; final int flex; final bool bold; const _BodyFlex(this.text,this.flex,{this.bold=false}); @override Widget build(BuildContext context) => Expanded(flex:flex, child: Padding(padding: const EdgeInsets.only(right:8), child: Text(text, style: GoogleFonts.dmSans(fontSize:12.5, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, height:1.5, color: AppColors.ink)))); }
class _TableHead extends StatelessWidget { final String text; const _TableHead(this.text); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(12), child: Text(text, style: GoogleFonts.dmSans(fontSize:12, fontWeight:FontWeight.w700, color: AppColors.tealDeep))); }
class _TableCell extends StatelessWidget { final String text; const _TableCell({required this.text}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(12), child: Text(text, style: GoogleFonts.dmSans(fontSize:13, color: AppColors.inkMid))); }
