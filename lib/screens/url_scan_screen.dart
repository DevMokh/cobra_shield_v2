import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../services/history_store.dart';
import '../services/inbox.dart';
import '../services/link_expander.dart';
import '../services/url_analyzer.dart';
import '../widgets/common.dart';
import '../widgets/scale_header.dart';
import '../widgets/scan_report.dart';

class UrlScanScreen extends StatefulWidget {
  const UrlScanScreen({super.key});

  @override
  State<UrlScanScreen> createState() => _UrlScanScreenState();
}

class _UrlScanScreenState extends State<UrlScanScreen> {
  final TextEditingController _ctrl = TextEditingController();
  ScanResult? _result;
  ExpandResult? _expand;
  ScanResult? _finalResult;
  bool _expanding = false;

  @override
  void initState() {
    super.initState();
    Inbox.toUrl.addListener(_onInbox);
  }

  @override
  void dispose() {
    Inbox.toUrl.removeListener(_onInbox);
    _ctrl.dispose();
    super.dispose();
  }

  // رابط جاي من المشاركة أو من تنبيه الحافظة
  void _onInbox() {
    final inc = Inbox.toUrl.value;
    if (inc == null || !mounted) return;
    _ctrl.text = inc.text;
    _scan();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim();
    if (t == null || t.isEmpty) {
      if (mounted) toast(context, 'الحافظة فاضية');
      return;
    }
    _ctrl.text = t;
    _scan();
  }

  void _clear() {
    _ctrl.clear();
    setState(() {
      _result = null;
      _expand = null;
      _finalResult = null;
    });
  }

  void _scan() {
    FocusScope.of(context).unfocus();
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      toast(context, 'الصق رابطًا أو اكتبه أولًا');
      return;
    }
    final r = UrlAnalyzer.analyze(raw);
    setState(() {
      _result = r;
      _expand = null;
      _finalResult = null;
    });
    final name = r.parts?.domain ?? raw;
    final short = name.length > 60 ? '${name.substring(0, 60)}...' : name;
    HistoryStore.instance.add(HistoryItem(
      id: DateTime.now().microsecondsSinceEpoch,
      kind: ScanKind.url,
      title: short,
      score: r.score,
      time: DateTime.now(),
    ));
  }

  Future<void> _expandLink() async {
    final r = _result;
    final p = r?.parts;
    if (p == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface2,
        title: const Text('فحص الوجهة الفعلية'),
        content: const Text(
          'هيتم الاتصال بالرابط للكشف عن التحويلات فقط (بدون تحميل أي محتوى أو فتح صفحة). '
          'الموقع سيعرف أن جهازك اتصل به وعنوان الإنترنت الخاص بك.\n\nهل تريد المتابعة؟',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: C.emerald,
              foregroundColor: C.onAccent,
            ),
            child: const Text('تابع'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _expanding = true);
    final res = await LinkExpander.expand(p.normalizedUrl);
    if (!mounted) return;
    ScanResult? fin;
    if (res.error == null && res.redirected) {
      fin = UrlAnalyzer.analyze(res.finalUrl);
    }
    setState(() {
      _expanding = false;
      _expand = res;
      _finalResult = fin;
    });
  }

  Widget _inputPanel() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: C.text,
            ),
            decoration: fieldDecoration(
              hint: 'https://example.com/login',
              suffix: IconButton(
                icon: const Icon(Icons.close_rounded, color: C.muted),
                onPressed: _clear,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: _scan,
                  style: filledButtonStyle(),
                  icon: const Icon(Icons.radar_rounded),
                  label: const Text('افحص الرابط'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _paste,
                  style: outlineButtonStyle(),
                  icon: const Icon(Icons.content_paste_rounded, size: 18),
                  label: const Text('لصق'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'الفحص يتم داخل جهازك بدون إرسال الرابط لأي جهة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _expandPanel(ScanResult r) {
    final e = _expand;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.alt_route_rounded, color: C.emerald, size: 20),
              SizedBox(width: 8),
              Text(
                'اكشف الوجهة الحقيقية',
                style: TextStyle(color: C.text, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'يتتبع التحويلات خطوة بخطوة ليكشف أين يوصلك الرابط فعلًا (مفيد جدًا مع الروابط المختصرة). يتطلب إنترنت.',
            style: TextStyle(color: C.muted, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 10),
          if (_expanding)
            const LinearProgressIndicator(color: C.emerald, minHeight: 3)
          else
            OutlinedButton.icon(
              onPressed: _expandLink,
              style: outlineButtonStyle(),
              icon: const Icon(Icons.travel_explore_rounded, size: 18),
              label: Text(e == null ? 'فحص الوجهة الفعلية' : 'إعادة الفحص'),
            ),
          if (e != null && !_expanding) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < e.chain.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: alpha(C.emerald, 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: C.emerald, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: SelectableText(
                          e.chain[i],
                          style: const TextStyle(
                            color: C.text,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (e.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  e.error!,
                  style: const TextStyle(color: C.amber, fontSize: 12.5),
                ),
              )
            else if (!e.redirected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'الرابط لا يعيد التوجيه (حالة السيرفر: ${e.statusCode ?? '-'}).',
                  style: const TextStyle(color: C.muted, fontSize: 12.5),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const ScaleHeader(
          title: 'Cobra Shield',
          subtitle: 'افحص الرابط قبل ما تفتحه',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _inputPanel(),
              if (r != null) ...[
                const SizedBox(height: 16),
                ScanSummaryCard(result: r),
                if (r.parts != null) ...[
                  const SizedBox(height: 14),
                  UrlBreakdown(parts: r.parts!),
                  const SizedBox(height: 14),
                  _expandPanel(r),
                ],
                if (_finalResult != null) ...[
                  const SizedBox(height: 16),
                  ScanSummaryCard(
                    result: _finalResult!,
                    heading: 'تحليل الوجهة النهائية',
                  ),
                  const SizedBox(height: 14),
                  FindingsList(
                    findings: _finalResult!.findings,
                    title: 'تفاصيل الوجهة النهائية',
                  ),
                ],
                const SizedBox(height: 14),
                FindingsList(findings: r.findings),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
