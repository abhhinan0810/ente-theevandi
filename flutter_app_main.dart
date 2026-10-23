import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Android emulator: 10.0.2.2 reaches the host computer.
// Physical phone: replace with your laptop's LAN IP address.
const String apiBase = 'http://10.0.2.2:5000/api';

void main() => runApp(const TrainCrowdApp());

class TrainCrowdApp extends StatelessWidget {
  const TrainCrowdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Train Crowd',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<dynamic>> trainsFuture;

  @override
  void initState() {
    super.initState();
    trainsFuture = loadTrains();
  }

  Future<List<dynamic>> loadTrains() async {
    final response = await http.get(Uri.parse('$apiBase/trains'));
    if (response.statusCode != 200) {
      throw Exception('Could not load trains (${response.statusCode})');
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Train Crowd Monitor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Current station'),
              subtitle: const Text('Location detection will be added in a later phase'),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Upcoming / available trains',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<List<dynamic>>(
            future: trainsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}\\nCheck Flask server and API URL.');
              }
              final trains = snapshot.data ?? [];
              if (trains.isEmpty) return const Text('No train records found.');
              return Column(
                children: trains.map((raw) {
                  final train = raw as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      title: Text('${train['number']} · ${train['name']}'),
                      subtitle: Text('${train['origin']} → ${train['destination']}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CrowdPage(
                          trainId: train['id'] as int,
                          trainName: train['name'] as String,
                        ),
                      )),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class CrowdPage extends StatefulWidget {
  final int trainId;
  final String trainName;
  const CrowdPage({super.key, required this.trainId, required this.trainName});

  @override
  State<CrowdPage> createState() => _CrowdPageState();
}

class _CrowdPageState extends State<CrowdPage> {
  late Future<List<dynamic>> coachesFuture;
  @override
  void initState() {
    super.initState();
    coachesFuture = loadCoaches();
  }

  Future<List<dynamic>> loadCoaches() async {
    final response = await http.get(
      Uri.parse('$apiBase/trains/${widget.trainId}/coaches'),
    );
    if (response.statusCode != 200) throw Exception('Could not load coaches');
    return jsonDecode(response.body) as List<dynamic>;
  }

  Color crowdColor(String level) {
    switch (level) {
      case 'Low': return Colors.green.shade100;
      case 'Medium': return Colors.amber.shade100;
      case 'High': return Colors.red.shade100;
      default: return Colors.grey.shade200;
    }
  }

  Future<void> submitReport(int coachId, String level) async {
    final response = await http.post(
      Uri.parse('$apiBase/crowd-reports'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'coach_id': coachId,
        'level': level,
        'station_name': 'Demo station',
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Report failed: ${response.body}');
    }
    setState(() { coachesFuture = loadCoaches(); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.trainName)),
      body: FutureBuilder<List<dynamic>>(
        future: coachesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          final coaches = snapshot.data ?? [];
          if (coaches.isEmpty) return const Center(child: Text('No General coaches configured.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('General coach crowd levels',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: coaches.map((raw) {
                  final c = raw as Map<String, dynamic>;
                  return Container(
                    width: 105,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: crowdColor(c['level'] as String),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      Text(c['code'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(c['level'] as String),
                      Text('${c['reports']} reports',
                          style: const TextStyle(fontSize: 11)),
                    ]),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text('Submit a crowd report',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Text('Choose the coach you are observing and report its crowd level.'),
              ...coaches.map((raw) {
                final c = raw as Map<String, dynamic>;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['code'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Wrap(
                          spacing: 8,
                          children: ['Low', 'Medium', 'High'].map((level) =>
                            OutlinedButton(
                              onPressed: () async {
                                try {
                                  await submitReport(c['id'] as int, level);
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Crowd report saved')),
                                  );
                                } catch (e) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$e')),
                                  );
                                }
                              },
                              child: Text(level),
                            )).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
