import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// EMAIL / BACKEND CONFIG
const String senderEmail = 'belal.salem@ejust.edu.eg'; // sender address (requested)

// Backend endpoint to actually send the email (optional, but needed to control "From")
const String emailApiEndpoint = ""; // e.g. https://your-api/send-email

// Simple placeholders you'll replace later
const String emailApiUser = senderEmail;
const String emailApiPassword = '1478523690dD'; // ← placeholder password you asked for

class GHGReporterFragment extends StatefulWidget {
  const GHGReporterFragment({super.key});
  @override
  State<GHGReporterFragment> createState() => _GHGReporterFragmentState();
}

class _GHGReporterFragmentState extends State<GHGReporterFragment> {
  // Org & period
  final _orgCtrl = TextEditingController(text: 'Acme HQ Campus');
  final _periodStartCtrl = TextEditingController(text: '2025-01-01');
  final _periodEndCtrl = TextEditingController(text: '2025-12-31');
  final _reporterNameCtrl = TextEditingController(text: 'Energy & Carbon Reporter');

  // Boundaries
  String _orgBoundary = 'Operational control';
  bool _includeScope3 = false;
  bool _useMarketBased = false;

  // Current period activity
  final _electricityKwhCtrl = TextEditingController(text: '125000');
  final _naturalGasThermsCtrl = TextEditingController(text: '4200');
  final _dieselLitersCtrl = TextEditingController(text: '800');
  final _floorAreaM2Ctrl = TextEditingController(text: '15000');

  // Baseline (previous period)
  final _baselineElectricityKwhCtrl = TextEditingController(text: '150000');
  final _baselineNaturalGasThermsCtrl = TextEditingController(text: '5000');
  final _baselineDieselLitersCtrl = TextEditingController(text: '900');

  // Emission factors (replace with authoritative ones for your locale/period)
  final _gridFactorCtrl = TextEditingController(text: '0.45');       // kgCO2e/kWh
  final _marketBasedGridFactorCtrl = TextEditingController(text: '0.38');
  final _gasFactorCtrl = TextEditingController(text: '5.31');        // kgCO2e/therm
  final _dieselFactorCtrl = TextEditingController(text: '2.68');     // kgCO2e/L

  // Email
  final _emailCtrl = TextEditingController(text: 'sustainability@acme.com');

  _ReportResult? _lastResult;
  bool _isBusy = false;

  @override
  void dispose() {
    _orgCtrl.dispose();
    _periodStartCtrl.dispose();
    _periodEndCtrl.dispose();
    _reporterNameCtrl.dispose();
    _electricityKwhCtrl.dispose();
    _naturalGasThermsCtrl.dispose();
    _dieselLitersCtrl.dispose();
    _floorAreaM2Ctrl.dispose();
    _baselineElectricityKwhCtrl.dispose();
    _baselineNaturalGasThermsCtrl.dispose();
    _baselineDieselLitersCtrl.dispose();
    _gridFactorCtrl.dispose();
    _marketBasedGridFactorCtrl.dispose();
    _gasFactorCtrl.dispose();
    _dieselFactorCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Compute totals + reductions vs baseline
  _ReportResult _compute() {
    double p(TextEditingController c) =>
        double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0.0;

    final useMarket = _useMarketBased;

    // Current
    final elec = p(_electricityKwhCtrl);
    final gas = p(_naturalGasThermsCtrl);
    final diesel = p(_dieselLitersCtrl);
    final area = p(_floorAreaM2Ctrl);
    final gridFactor = useMarket ? p(_marketBasedGridFactorCtrl) : p(_gridFactorCtrl);
    final gasFactor = p(_gasFactorCtrl);
    final dieselFactor = p(_dieselFactorCtrl);

    final scope2Kg = elec * gridFactor;
    final scope1Kg = gas * gasFactor + diesel * dieselFactor;
    final scope3Kg = _includeScope3 ? 0.0 : 0.0; // placeholder
    final totalKg = scope1Kg + scope2Kg + scope3Kg;

    // Baseline
    final baseElec = p(_baselineElectricityKwhCtrl);
    final baseGas = p(_baselineNaturalGasThermsCtrl);
    final baseDiesel = p(_baselineDieselLitersCtrl);

    final baseScope2Kg = baseElec * gridFactor; // same basis for fair comparison
    final baseScope1Kg = baseGas * gasFactor + baseDiesel * dieselFactor;
    final baseTotalKg = baseScope1Kg + baseScope2Kg;

    // Reductions (clip at ≥ 0 for realism)
    final energyReducedKwh = (baseElec - elec).clamp(0, double.infinity);
    final co2ReducedKg = (baseTotalKg - totalKg).clamp(0, double.infinity);

    return _ReportResult(
      orgName: _orgCtrl.text.trim(),
      reporter: _reporterNameCtrl.text.trim(),
      periodStart: _periodStartCtrl.text.trim(),
      periodEnd: _periodEndCtrl.text.trim(),
      orgBoundary: _orgBoundary,
      scope2Basis: useMarket ? 'Market-based' : 'Location-based',
      includeScope3: _includeScope3,
      useMarketBased: useMarket,
      // current
      electricityKwh: elec,
      naturalGasTherms: gas,
      dieselLiters: diesel,
      gridFactorKgPerKwh: gridFactor,
      gasFactorKgPerTherm: gasFactor,
      dieselFactorKgPerLiter: dieselFactor,
      scope1Kg: scope1Kg,
      scope2Kg: scope2Kg,
      scope3Kg: scope3Kg,
      totalKg: totalKg,
      intensityKgPerM2: area > 0 ? totalKg / area : 0.0,
      floorAreaM2: area,
      // baseline
      baseElectricityKwh: baseElec,
      baseNaturalGasTherms: baseGas,
      baseDieselLiters: baseDiesel,
      baseScope1Kg: baseScope1Kg,
      baseScope2Kg: baseScope2Kg,
      baseTotalKg: baseTotalKg,
      // reductions
      energyReducedKwh: energyReducedKwh,
      co2ReducedKg: co2ReducedKg,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // File helpers
  Future<Directory> _appDir() async {
    if (kIsWeb) return Directory.systemTemp.createTemp('ghg_report_web_');
    return getTemporaryDirectory();
  }

  String _fmt(num v, {int dec = 0}) {
    final s = v.toStringAsFixed(dec);
    final parts = s.split('.');
    final re = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final whole = parts[0].replaceAllMapped(re, (m) => ',');
    return parts.length == 2 && dec > 0 ? '$whole.${parts[1]}' : whole;
  }

  Future<File> _writeCsv(_ReportResult r) async {
    final dir = await _appDir();
    final path =
        '${dir.path}/ghg_report_${r.periodStart}_${r.periodEnd}.csv'.replaceAll(' ', '_');
    final f = File(path);

    final csv = StringBuffer()
      ..writeln('Section,Field,Value,Unit')
      ..writeln('Organization,Name,${r.orgName},')
      ..writeln('Reporting,Period Start,${r.periodStart},')
      ..writeln('Reporting,Period End,${r.periodEnd},')
      ..writeln('Boundary,Organizational Boundary,${r.orgBoundary},')
      ..writeln('Boundary,Scope 2 Basis,${r.scope2Basis},')
      ..writeln('Activity (Current),Electricity,${r.electricityKwh.toStringAsFixed(2)},kWh')
      ..writeln('Activity (Current),Natural Gas,${r.naturalGasTherms.toStringAsFixed(2)},therm')
      ..writeln('Activity (Current),Diesel,${r.dieselLiters.toStringAsFixed(2)},L')
      ..writeln('Activity (Baseline),Electricity,${r.baseElectricityKwh.toStringAsFixed(2)},kWh')
      ..writeln('Activity (Baseline),Natural Gas,${r.baseNaturalGasTherms.toStringAsFixed(2)},therm')
      ..writeln('Activity (Baseline),Diesel,${r.baseDieselLiters.toStringAsFixed(2)},L')
      ..writeln('Factors,Grid Factor,${r.gridFactorKgPerKwh},kgCO2e/kWh')
      ..writeln('Factors,Gas Factor,${r.gasFactorKgPerTherm},kgCO2e/therm')
      ..writeln('Factors,Diesel Factor,${r.dieselFactorKgPerLiter},kgCO2e/L')
      ..writeln('Emissions (Current),Scope 1,${r.scope1Kg.toStringAsFixed(2)},kgCO2e')
      ..writeln('Emissions (Current),Scope 2,${r.scope2Kg.toStringAsFixed(2)},kgCO2e')
      ..writeln('Emissions (Current),Total,${r.totalKg.toStringAsFixed(2)},kgCO2e')
      ..writeln('Emissions (Baseline),Scope 1,${r.baseScope1Kg.toStringAsFixed(2)},kgCO2e')
      ..writeln('Emissions (Baseline),Scope 2,${r.baseScope2Kg.toStringAsFixed(2)},kgCO2e')
      ..writeln('Emissions (Baseline),Total,${r.baseTotalKg.toStringAsFixed(2)},kgCO2e')
      ..writeln('Reductions,Energy Reduced,${r.energyReducedKwh.toStringAsFixed(2)},kWh')
      ..writeln('Reductions,CO2e Avoided,${r.co2ReducedKg.toStringAsFixed(2)},kgCO2e')
      ..writeln('Intensity,Per m²,${r.intensityKgPerM2.toStringAsFixed(4)},kgCO2e/m²')
      ..writeln('Notes,Methodology,GHG Protocol Corporate Standard,');

    await f.writeAsString(csv.toString());
    return f;
  }

  // PDF helpers to render "CO₂e" even if font lacks subscript glyph
  pw.Widget _co2eWord(pw.TextStyle style) {
    final small = style.copyWith(fontSize: (style.fontSize ?? 11) * 0.75);
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text('CO', style: style),
        pw.Transform.translate(
          offset: PdfPoint(0, -2), // shift the 2 down → subscript
          child: pw.Text('2', style: small),
        ),
        pw.Text('e', style: style),
      ],
    );
  }

  pw.Widget _kgCo2eValue(num value, pw.TextStyle style) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('${_fmt(value, dec: 0)} ', style: style),
        pw.Text('kg ', style: style),
        _co2eWord(style),
      ],
    );
  }

  pw.Widget _kgCo2ePerM2(num value, pw.TextStyle style) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(value.toStringAsFixed(4) + ' kg ', style: style),
        _co2eWord(style),
        pw.Text('/m²', style: style),
      ],
    );
  }

  Future<File> _writePdf(_ReportResult r) async {
    final pdf = pw.Document();
    final h1 = pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold);
    final h2 = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
    final body = pw.TextStyle(fontSize: 11);

    pw.Widget rowS(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 3, child: pw.Text(k, style: body)),
              pw.SizedBox(width: 8),
              pw.Expanded(flex: 7, child: pw.Text(v, style: body)),
            ],
          ),
        );

    pw.Widget rowW(String k, pw.Widget v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 3, child: pw.Text(k, style: body)),
              pw.SizedBox(width: 8),
              pw.Expanded(flex: 7, child: v),
            ],
          ),
        );

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text('GHG Inventory Report', style: h1),
          pw.SizedBox(height: 6),
          pw.Text(
              'Aligned with the Greenhouse Gas Protocol (Corporate Accounting and Reporting Standard)',
              style: body),
          pw.SizedBox(height: 12),

          // Big reductions at the top (Energy & CO₂e)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.6),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Energy Reduced', style: h2),
                      pw.Text('${_fmt(r.energyReducedKwh, dec: 0)} kWh',
                          style: pw.TextStyle(
                              fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(children: [
                        _co2eWord(h2),
                        pw.Text(' Avoided', style: h2),
                      ]),
                      _kgCo2eValue(r.co2ReducedKg, pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold,
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),
          pw.Text('1. Reporting Organization & Period', style: h2),
          rowS('Organization', r.orgName),
          rowS('Reporting Period', '${r.periodStart} to ${r.periodEnd}'),
          rowS('Prepared By', r.reporter),

          pw.SizedBox(height: 8),
          pw.Text('2. Boundaries', style: h2),
          rowS('Organizational Boundary', r.orgBoundary),
          rowS('Operational Boundaries',
              'Scopes 1 & 2${r.includeScope3 ? " (+ Scope 3 placeholder)" : ""}'),
          rowS('Scope 2 Basis', r.scope2Basis),

          pw.SizedBox(height: 8),
          pw.Text('3. Activity Data (Current vs Baseline)', style: h2),
          rowS('Electricity (current/baseline)',
              '${_fmt(r.electricityKwh, dec: 0)} / ${_fmt(r.baseElectricityKwh, dec: 0)} kWh'),
          rowS('Natural Gas (current/baseline)',
              '${_fmt(r.naturalGasTherms, dec: 0)} / ${_fmt(r.baseNaturalGasTherms, dec: 0)} therms'),
          rowS('Diesel (current/baseline)',
              '${_fmt(r.dieselLiters, dec: 0)} / ${_fmt(r.baseDieselLiters, dec: 0)} L'),
          if (r.floorAreaM2 > 0)
            rowS('Floor Area', '${_fmt(r.floorAreaM2, dec: 0)} m²'),

          pw.SizedBox(height: 8),
          pw.Text('4. Emission Factors', style: h2),
          rowS('Grid Factor', '${r.gridFactorKgPerKwh} kgCO2e/kWh'),
          rowS('Natural Gas Factor', '${r.gasFactorKgPerTherm} kgCO2e/therm'),
          rowS('Diesel Factor', '${r.dieselFactorKgPerLiter} kgCO2e/L'),

          pw.SizedBox(height: 8),
          pw.Text('5. Emissions', style: h2),
          rowW('Scope 1 (current/baseline)',
              pw.Row(children: [
                _kgCo2eValue(r.scope1Kg, body),
                pw.Text(' / ', style: body),
                _kgCo2eValue(r.baseScope1Kg, body),
              ])),
          rowW('Scope 2 (current/baseline, ${r.scope2Basis})',
              pw.Row(children: [
                _kgCo2eValue(r.scope2Kg, body),
                pw.Text(' / ', style: body),
                _kgCo2eValue(r.baseScope2Kg, body),
              ])),
          rowW('Total (current/baseline)',
              pw.Row(children: [
                _kgCo2eValue(r.totalKg, body),
                pw.Text(' / ', style: body),
                _kgCo2eValue(r.baseTotalKg, body),
              ])),

          pw.SizedBox(height: 8),
          pw.Text('6. Reductions vs Baseline', style: h2),
          rowS('Energy Reduced', '${_fmt(r.energyReducedKwh, dec: 0)} kWh'),
          rowW('CO₂e Avoided', _kgCo2eValue(r.co2ReducedKg, body)),
          if (r.floorAreaM2 > 0)
            rowW('Intensity (current)', _kgCo2ePerM2(r.intensityKgPerM2, body)),

          pw.SizedBox(height: 8),
          pw.Text('7. Methodology & Notes', style: h2),
          pw.Bullet(text: 'Methodology: GHG Protocol Corporate Accounting and Reporting Standard.'),
          pw.Bullet(text: 'Scope 2 method: ${r.scope2Basis}. Replace default factors with location- and period-specific authoritative values.'),
          pw.Bullet(text: 'Reductions compare current period to baseline using identical factors.'),
        ],
      ),
    );

    final dir = await _appDir();
    final path =
        '${dir.path}/ghg_report_${r.periodStart}_${r.periodEnd}.pdf'.replaceAll(' ', '_');
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> _emailReport(File pdfFile, _ReportResult r) async {
    final recipient = _emailCtrl.text.trim();
    if (recipient.isEmpty) {
      _snack('Please enter a recipient email.');
      return;
    }

    // Preferred: backend send (so we can really set "From")
    if (emailApiEndpoint.isNotEmpty) {
      try {
        final bytes = await pdfFile.readAsBytes();
        final payload = {
          "from": senderEmail,
          "to": recipient,
          "subject": "GHG Report ${r.orgName} ${r.periodStart}–${r.periodEnd}",
          "body": "Please find the attached GHG report.",
          "attachments": [
            {
              "filename": pdfFile.uri.pathSegments.last,
              "content_base64": base64Encode(bytes),
            }
          ],
        };
        final headers = {
          'Content-Type': 'application/json',
          // simple placeholders so you can wire any backend auth you like
          'X-Email-User': emailApiUser,
          'X-Email-Password': emailApiPassword, // ← "belal"
        };

        final resp = await http.post(
          Uri.parse(emailApiEndpoint),
          headers: headers,
          body: jsonEncode(payload),
        );
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          _snack('Report emailed to $recipient from $senderEmail');
          return;
        } else {
          _snack('Backend email failed: ${resp.statusCode}');
        }
      } catch (e) {
        _snack('Backend email error: $e');
      }
    }

    // Fallbacks (client controls the From)
    try {
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text:
            'GHG Report ${r.orgName} ${r.periodStart}–${r.periodEnd}\n(From: $senderEmail — the actual sender depends on your mail app)',
        subject: 'GHG Report',
      );
    } catch (_) {
      final uri = Uri(
        scheme: 'mailto',
        path: recipient,
        queryParameters: {
          'subject': 'GHG Report ${r.orgName} ${r.periodStart}–${r.periodEnd}',
          'body':
              'From: $senderEmail\nPlease see the attached report (downloaded locally). If not attached automatically, attach the PDF found at:\n${pdfFile.path}',
        },
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _snack('Could not launch email client.');
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI

  InputDecoration _deco(String hint) => InputDecoration(
        labelText: hint,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _numField(String label, TextEditingController c, {String? suffix}) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _deco(label).copyWith(suffixText: suffix),
    );
  }

  // LEFT: made scrollable to eliminate rare “overflow by 2 pixels”
  Widget _buildLeftInputs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (_, __) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GHG Report Inputs',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo)),
              const Divider(height: 20),

              // Organization & Period
              TextField(controller: _orgCtrl, decoration: _deco('Organization')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _periodStartCtrl,
                          decoration: _deco('Period Start (YYYY-MM-DD)'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: _periodEndCtrl,
                          decoration: _deco('Period End (YYYY-MM-DD)'))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: _reporterNameCtrl, decoration: _deco('Prepared By')),

              const SizedBox(height: 14),
              // Boundaries
              const Text('Organizational Boundary',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _orgBoundary,
                decoration: _deco('Boundary'),
                items: const [
                  DropdownMenuItem(
                      value: 'Operational control', child: Text('Operational control')),
                  DropdownMenuItem(
                      value: 'Financial control', child: Text('Financial control')),
                  DropdownMenuItem(value: 'Equity share', child: Text('Equity share')),
                ],
                onChanged: (v) => setState(() => _orgBoundary = v ?? _orgBoundary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      dense: true,
                      title: const Text('Scope 3 (placeholder)'),
                      value: _includeScope3,
                      onChanged: (v) => setState(() => _includeScope3 = v),
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      dense: true,
                      title: const Text('Scope 2: Market-based'),
                      value: _useMarketBased,
                      onChanged: (v) => setState(() => _useMarketBased = v),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Text('Activity Data — Current Period',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _numField('Electricity (kWh)', _electricityKwhCtrl, suffix: 'kWh'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _numField(
                          'Natural Gas (therms)', _naturalGasThermsCtrl,
                          suffix: 'therm')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _numField('Diesel (L)', _dieselLitersCtrl, suffix: 'L')),
                ],
              ),
              const SizedBox(height: 8),
              _numField('Floor Area (m²) – optional', _floorAreaM2Ctrl, suffix: 'm²'),

              const SizedBox(height: 12),
              const Text('Baseline — Previous Period',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _numField(
                  'Baseline Electricity (kWh)', _baselineElectricityKwhCtrl,
                  suffix: 'kWh'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _numField('Baseline Gas (therms)',
                          _baselineNaturalGasThermsCtrl,
                          suffix: 'therm')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _numField(
                          'Baseline Diesel (L)', _baselineDieselLitersCtrl,
                          suffix: 'L')),
                ],
              ),

              const SizedBox(height: 12),
              const Text('Emission Factors',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _numField('Grid Factor (kgCO2e/kWh)', _gridFactorCtrl, suffix: 'kg/kWh'),
              if (_useMarketBased) ...[
                const SizedBox(height: 8),
                _numField('Market-based Grid Factor (kgCO2e/kWh)',
                    _marketBasedGridFactorCtrl,
                    suffix: 'kg/kWh'),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _numField('Gas Factor (kgCO2e/therm)', _gasFactorCtrl,
                          suffix: 'kg/therm')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _numField('Diesel Factor (kgCO2e/L)', _dieselFactorCtrl,
                          suffix: 'kg/L')),
                ],
              ),

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.calculate),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: () {
                    final res = _compute();
                    setState(() => _lastResult = res);
                    _snack('Calculated. See preview on the right.');
                  },
                  label: const Text('Generate Preview'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // RIGHT
  Widget _buildRightPreview() {
    final r = _lastResult;

    // Larger KPI cards; responsive height (no fixed height → no tiny overflows)
    Widget bigCard({
      required IconData icon,
      required String title,
      required String value,
      String? subtitle,
      Color color = Colors.indigo,
    }) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // ← prevents tiny vertical spill
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget smallChip(IconData icon, String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.indigo, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.indigo)),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    Widget section(String title, List<Widget> children) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.indigo)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Email + sender display
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        decoration: InputDecoration(
                          labelText: 'Recipient Email',
                          hintText: 'name@company.com',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          helperText:
                              'Sender: $senderEmail (backend required to enforce sender)',
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── BIG KPIs (emphasis) ──
                if (r != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: bigCard(
                          icon: Icons.energy_savings_leaf,
                          title: 'Energy Reduced',
                          value: '${_fmt(r.energyReducedKwh, dec: 0)} kWh',
                          subtitle:
                              'Baseline ${_fmt(r.baseElectricityKwh, dec: 0)} → Current ${_fmt(r.electricityKwh, dec: 0)}',
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: bigCard(
                          icon: Icons.co2,
                          title: 'CO₂e Avoided',
                          value: '${_fmt(r.co2ReducedKg, dec: 0)} kg',
                          subtitle: 'Total CO₂e vs baseline (Scopes 1+2)',
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ] else
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'No preview yet. Enter inputs and click “Generate Preview”.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Smaller KPI chips
                if (r != null) Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    smallChip(Icons.local_fire_department, 'Scope 1 (now):',
                        '${_fmt(r.scope1Kg, dec: 0)} kg CO₂e'),
                    smallChip(Icons.bolt, 'Scope 2 (now):',
                        '${_fmt(r.scope2Kg, dec: 0)} kg CO₂e'),
                    smallChip(Icons.public, 'Total (now):',
                        '${_fmt(r.totalKg, dec: 0)} kg CO₂e'),
                    if (r.floorAreaM2 > 0)
                      smallChip(Icons.grid_on, 'Intensity:',
                          '${r.intensityKgPerM2.toStringAsFixed(3)} kg CO₂e/m²'),
                  ],
                ),

                const SizedBox(height: 12),

                // Details sections
                if (r != null) ...[
                  section('Reporting Organization & Period', [
                    _kv('Organization', r.orgName),
                    _kv('Reporting Period', '${r.periodStart} to ${r.periodEnd}'),
                    _kv('Prepared By', r.reporter),
                  ]),
                  section('Boundaries', [
                    _kv('Organizational Boundary', r.orgBoundary),
                    _kv('Operational Boundaries',
                        'Scopes 1 & 2${r.includeScope3 ? " (+ Scope 3 placeholder)" : ""}'),
                    _kv('Scope 2 Basis', r.scope2Basis),
                  ]),
                  section('Activity Data (Current vs Baseline)', [
                    _kv('Electricity',
                        '${_fmt(r.electricityKwh, dec: 0)} / ${_fmt(r.baseElectricityKwh, dec: 0)} kWh'),
                    _kv('Natural Gas',
                        '${_fmt(r.naturalGasTherms, dec: 0)} / ${_fmt(r.baseNaturalGasTherms, dec: 0)} therms'),
                    _kv('Diesel',
                        '${_fmt(r.dieselLiters, dec: 0)} / ${_fmt(r.baseDieselLiters, dec: 0)} L'),
                    if (r.floorAreaM2 > 0)
                      _kv('Floor Area', '${_fmt(r.floorAreaM2, dec: 0)} m²'),
                  ]),
                  section('Emission Factors', [
                    _kv('Grid Factor', '${r.gridFactorKgPerKwh} kgCO2e/kWh'),
                    _kv('Natural Gas Factor', '${r.gasFactorKgPerTherm} kgCO2e/therm'),
                    _kv('Diesel Factor', '${r.dieselFactorKgPerLiter} kgCO2e/L'),
                  ]),
                ],
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.file_download),
                    onPressed: _isBusy || _lastResult == null ? null : () async {
                      setState(() => _isBusy = true);
                      try {
                        final csv = await _writeCsv(_lastResult!);
                        _snack('CSV saved: ${csv.path}');
                      } finally {
                        setState(() => _isBusy = false);
                      }
                    },
                    label: const Text('Download CSV'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    onPressed: _isBusy || _lastResult == null ? null : () async {
                      setState(() => _isBusy = true);
                      try {
                        final pdf = await _writePdf(_lastResult!);
                        _snack('PDF saved: ${pdf.path}');
                      } finally {
                        setState(() => _isBusy = false);
                      }
                    },
                    label: const Text('Download PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    onPressed: _isBusy || _lastResult == null ? null : () async {
                      setState(() => _isBusy = true);
                      try {
                        final pdf = await _writePdf(_lastResult!);
                        await _emailReport(pdf, _lastResult!);
                      } finally {
                        setState(() => _isBusy = false);
                      }
                    },
                    label: const Text('Email Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helpers
  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 220,
              child: Text(k,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(v,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Expanded(flex: 4, child: _buildLeftInputs()),
            const SizedBox(width: 24),
            Expanded(flex: 6, child: _buildRightPreview()),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// RESULT MODEL
class _ReportResult {
  final String orgName;
  final String reporter;
  final String periodStart;
  final String periodEnd;
  final String orgBoundary;
  final String scope2Basis;
  final bool includeScope3;
  final bool useMarketBased;

  // current
  final double electricityKwh;
  final double naturalGasTherms;
  final double dieselLiters;
  final double gridFactorKgPerKwh;
  final double gasFactorKgPerTherm;
  final double dieselFactorKgPerLiter;
  final double scope1Kg;
  final double scope2Kg;
  final double scope3Kg;
  final double totalKg;
  final double intensityKgPerM2;
  final double floorAreaM2;

  // baseline
  final double baseElectricityKwh;
  final double baseNaturalGasTherms;
  final double baseDieselLiters;
  final double baseScope1Kg;
  final double baseScope2Kg;
  final double baseTotalKg;

  // reductions
  final num energyReducedKwh;
  final num co2ReducedKg;

  _ReportResult({
    required this.orgName,
    required this.reporter,
    required this.periodStart,
    required this.periodEnd,
    required this.orgBoundary,
    required this.scope2Basis,
    required this.includeScope3,
    required this.useMarketBased,
    required this.electricityKwh,
    required this.naturalGasTherms,
    required this.dieselLiters,
    required this.gridFactorKgPerKwh,
    required this.gasFactorKgPerTherm,
    required this.dieselFactorKgPerLiter,
    required this.scope1Kg,
    required this.scope2Kg,
    required this.scope3Kg,
    required this.totalKg,
    required this.intensityKgPerM2,
    required this.floorAreaM2,
    required this.baseElectricityKwh,
    required this.baseNaturalGasTherms,
    required this.baseDieselLiters,
    required this.baseScope1Kg,
    required this.baseScope2Kg,
    required this.baseTotalKg,
    required this.energyReducedKwh,
    required this.co2ReducedKg,
  });
}