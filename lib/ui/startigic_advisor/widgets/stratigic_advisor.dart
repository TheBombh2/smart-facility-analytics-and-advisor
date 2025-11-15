import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ──────────────────────────────────────────────────────────────────────────────
// GROQ API CONFIG (leave as-is for your env; move to backend for prod)
const String groqApiKey =
    'GROQ API KEY HERE';
const String groqModel = 'GROQ MODEL HERE';
const String systemInstruction =
    "You are a Strategic Energy Advisor. Provide concise, actionable advice on optimizing building energy use and comfort. Keep responses professional and brief, and focus on the provided building data context (consumption, comfort, occupancy, weather).";

// Ask LLM to provide machine-readable summary for totals
const String savingsVizInstruction = '''
At the end of your answer, add exactly one line in this format:
SAVINGS: {"energy_kwh": <number>, "cost_usd": <number>, "co2_kg": <number>, "water_l": <number>}
Use 0 if unknown. Do not add anything after this line, do not use very large not realistic numbers. keep it real.
''';

// ──────────────────────────────────────────────────────────────────────────────
// MOCK DATA FOR ALERTS (unchanged)
const List<Map<String, String>> _initialAlerts = [
  {
    'level': 'Critical',
    'message':
        'CRITICAL: Meeting Room (Area 35, Capacity 12). Energy consumption (51.7 kW) is 19.7% above baseline (43.2 kW) despite very low 22% occupancy. This indicates significant overcooling or a system anomaly. ID: E-101.'
  },
  {
    'level': 'Info',
    'message':
        'INFO: Reception Hall (Area 42, Capacity 30). Energy consumption (34.2 kW) is 4.9% below baseline (36.0 kW) with 72% occupancy. System performance within optimal range. ID: E-056.'
  },
  {
    'level': 'Critical',
    'message':
        'CRITICAL: Laboratory Wing (Area 58, Capacity 20). Energy consumption (73.5 kW) is 26.8% above baseline (58.0 kW) despite only 18% occupancy. Possible cause: ventilation running at full load. ID: E-207.'
  },
];

// ──────────────────────────────────────────────────────────────────────────────
// APP FRAGMENT

class StrategicAdvisorFragment extends StatefulWidget {
  const StrategicAdvisorFragment({super.key});

  @override
  State<StrategicAdvisorFragment> createState() =>
      _StrategicAdvisorFragmentState();
}

class SavingsPoint {
  final DateTime t;
  final double energyKwh;
  final double costUsd;
  final double co2Kg;
  final double waterL;
  const SavingsPoint({
    required this.t,
    required this.energyKwh,
    required this.costUsd,
    required this.co2Kg,
    required this.waterL,
  });
}

class _StrategicAdvisorFragmentState extends State<StrategicAdvisorFragment> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, String>> _activeAlerts = [];
  List<Map<String, String>> _chatHistory = [
    {
      'role': 'advisor',
      'text':
          'Hello! I\'m your Strategic Advisor. How can I assist with your building\'s performance today?'
    }
  ];
  bool _isLoading = false;

  final List<SavingsPoint> _savingsHistory = [];

  @override
  void initState() {
    super.initState();
    _activeAlerts = List.from(_initialAlerts);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────────
  Future<String> _fetchGroqResponse(String userQuery) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final combinedUserQuery = '$userQuery\n\n$savingsVizInstruction';

    final payload = {
      "model": groqModel,
      "messages": [
        {"role": "system", "content": systemInstruction},
        {"role": "user", "content": combinedUserQuery}
      ],
      "temperature": 0.6,
      "max_tokens": 1024,
      "top_p": 1.0,
      "stream": false
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqApiKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        return (content is String && content.trim().isNotEmpty)
            ? content
            : 'No response from advisor.';
      } else {
        debugPrint('Groq API Error: ${response.statusCode} - ${response.body}');
        return 'Error: Advisor service returned status ${response.statusCode}.';
      }
    } catch (e) {
      debugPrint('Groq API Exception: $e');
      return 'Error: Could not reach the advisor service.';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    _controller.clear();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _chatHistory.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final advisorResponse = await _fetchGroqResponse(text);
      _maybeIngestSavings(advisorResponse);
      setState(() {
        _chatHistory.add({'role': 'advisor', 'text': advisorResponse});
      });
    } catch (e) {
      setState(() {
        _chatHistory.add({
          'role': 'advisor',
          'text': 'Error: Could not connect to the advisor service.'
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _handleAlertAction(Map<String, String> alert, String action) async {
    final alertMessage = alert['message']!;
    setState(() {
      _activeAlerts.removeWhere((a) => a['message'] == alertMessage);
    });

    if (action == 'Accept') {
      final confirmation =
          'I accepted the "${alert['level']}" alert regarding: $alertMessage';

      setState(() {
        _chatHistory.add({'role': 'user', 'text': confirmation});
        _isLoading = true;
      });
      _scrollToBottom();

      try {
        final advisorResponse = await _fetchGroqResponse(confirmation);
        _maybeIngestSavings(advisorResponse);
        setState(() {
          _chatHistory.add({'role': 'advisor', 'text': advisorResponse});
        });
      } catch (e) {
        setState(() {
          _chatHistory.add({
            'role': 'advisor',
            'text': 'Error: Could not log action with the advisor service.'
          });
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _handleAlertTap(Map<String, String> alert) {
    _controller.text =
        'Explain the ${alert['level']} alert in detail: ${alert['message']}';
    FocusScope.of(context).requestFocus(FocusNode());
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Parse "SAVINGS: {...}" line; regex fallback if needed
  void _maybeIngestSavings(String advisorText) {
    final jsonLine = RegExp(r'SAVINGS\s*:\s*(\{.*?\})',
            dotAll: true, caseSensitive: false)
        .firstMatch(advisorText);
    double energy = 0, cost = 0, co2 = 0, water = 0;

    if (jsonLine != null) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(jsonLine.group(1)!);
        energy = (parsed['energy_kwh'] ?? 0).toDouble();
        cost = (parsed['cost_usd'] ?? 0).toDouble();
        co2 = (parsed['co2_kg'] ?? 0).toDouble();
        water = (parsed['water_l'] ?? 0).toDouble();
      } catch (_) {/* ignore */}
    }

    if (jsonLine == null || (energy == 0 && cost == 0 && co2 == 0 && water == 0)) {
      energy = _pullFirstNumber(RegExp(r'(?i)(?:saved|reduced).*?(\d+(?:\.\d+)?)\s*kwh'), advisorText) ?? 0;
      cost   = _pullFirstNumber(RegExp(r'(?i)(?:\$|usd)\s*(\d+(?:\.\d+)?)'), advisorText) ?? 0;
      co2    = _pullFirstNumber(RegExp(r'(?i)co2e?\D*(\d+(?:\.\d+)?)\s*kg'), advisorText) ?? 0;
      water  = _pullFirstNumber(RegExp(r'(?i)(\d+(?:\.\d+)?)\s*(?:l|lit(er|re)s?)\b'), advisorText) ?? 0;
    }

    if (energy == 0 && cost == 0 && co2 == 0 && water == 0) return;

    setState(() {
      _savingsHistory.add(SavingsPoint(
        t: DateTime.now(),
        energyKwh: energy,
        costUsd: cost,
        co2Kg: co2,
        waterL: water,
      ));
    });
  }

  double? _pullFirstNumber(RegExp r, String text) {
    final m = r.firstMatch(text);
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', ''));
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Savings panel: only small KPI cards (no graphs)
  Widget _buildSavingsPanel() {
    if (_savingsHistory.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: const [
              Icon(Icons.insights, color: Colors.indigo),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Savings & Impact: No data yet. Ask the advisor for optimization actions to see live savings.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalEnergy =
        _savingsHistory.fold<double>(0, (s, p) => s + p.energyKwh);
    final totalCost = _savingsHistory.fold<double>(0, (s, p) => s + p.costUsd);
    final totalCO2 = _savingsHistory.fold<double>(0, (s, p) => s + p.co2Kg);
    final totalWater = _savingsHistory.fold<double>(0, (s, p) => s + p.waterL);

    Widget kpiChip(IconData icon, String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.indigo, size: 18),
            const SizedBox(width: 6),
            Text('$label: ',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.indigo)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            kpiChip(Icons.flash_on, 'Energy Saved',
                '${totalEnergy.toStringAsFixed(1)} kWh'),
            kpiChip(Icons.attach_money, 'Cost Saved',
                '\$${totalCost.toStringAsFixed(2)}'),
            kpiChip(Icons.cloud_done, 'CO₂ Avoided',
                '${totalCO2.toStringAsFixed(1)} kg'),
            kpiChip(Icons.water_drop, 'Water Saved',
                '${totalWater.toStringAsFixed(0)} L'),
          ],
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildAlertsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proactive Alerts & Suggestions',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
          const Divider(height: 20),
          Expanded(
            child: _activeAlerts.isEmpty
                ? const Center(
                    child: Text('No active alerts.',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: _activeAlerts.length,
                    itemBuilder: (context, index) {
                      final alert = _activeAlerts[index];
                      Color color;
                      IconData icon;

                      switch (alert['level']) {
                        case 'Critical':
                          color = Colors.deepPurple.shade700;
                          icon = Icons.crisis_alert;
                          break;
                        case 'Info':
                        default:
                          color = Colors.lightBlue.shade700;
                          icon = Icons.info;
                          break;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                              color: color.withOpacity(0.5), width: 1),
                        ),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => _handleAlertTap(alert),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(icon, color: color, size: 30),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            alert['level']!,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                                fontSize: 16),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            alert['message']!,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.send,
                                        color: Colors.grey, size: 20),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.only(
                                  left: 16, right: 16, bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        _handleAlertAction(alert, 'Dismiss'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.grey.shade600,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('DISMISS'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _handleAlertAction(
                                            alert, 'Accept'),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('ACCEPT'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigo,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, String role) {
    final isAdvisor = role == 'advisor';
    return Align(
      alignment: isAdvisor ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.4,
        ),
        decoration: BoxDecoration(
          color: isAdvisor ? Colors.grey.shade200 : Colors.indigo.shade400,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isAdvisor ? const Radius.circular(4) : const Radius.circular(16),
            bottomRight:
                isAdvisor ? const Radius.circular(16) : const Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isAdvisor ? Colors.black87 : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildChatSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          // Chat History
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 10),
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final message = _chatHistory[index];
                return _buildChatBubble(message['text']!, message['role']!);
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: Colors.indigo),
            ),

          // Savings KPI chips (no graphs)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: _buildSavingsPanel(),
          ),

          // Input Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: 'Ask the Strategic Advisor...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: _isLoading ? null : _sendMessage,
                  backgroundColor: _isLoading ? Colors.grey : Colors.indigo,
                  elevation: 0,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Expanded(flex: 4, child: _buildAlertsSection()),
            const SizedBox(width: 24),
            Expanded(flex: 6, child: _buildChatSection()),
          ],
        ),
      ),
    );
  }
}