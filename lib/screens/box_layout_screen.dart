import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BoxLayoutScreen extends StatefulWidget {
  const BoxLayoutScreen({super.key});

  @override
  State<BoxLayoutScreen> createState() => _BoxLayoutScreenState();
}

class _BoxLayoutScreenState extends State<BoxLayoutScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _boxes = [];
  List<Map<String, dynamic>> _dogs = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _movimenti = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final boxesRes = await supabase.from('boxes').select('*').order('name');
      final dogsRes = await supabase.from('dogs').select('*');
      final bookingsRes = await supabase.from('bookings').select('*');
      final movimentiRes = await supabase.from('movimenti').select('*');

      _boxes = List<Map<String, dynamic>>.from(boxesRes);
      _dogs = List<Map<String, dynamic>>.from(dogsRes);
      _bookings = List<Map<String, dynamic>>.from(bookingsRes);
      _movimenti = List<Map<String, dynamic>>.from(movimentiRes);
    } catch (e) {
      print('❌ Errore caricamento: $e');
    }
    setState(() => _isLoading = false);
  }

  // Calcola l'occupazione per una data specifica
  Map<String, List<String>> _getOccupancyForDate(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final Map<String, List<String>> occupancy = {};

    // Inizializza tutti i box vuoti
    for (var box in _boxes) {
      occupancy[box['id']] = [];
    }

    // 1. Prenotazioni attive
    for (var booking in _bookings) {
      final start = booking['start_date'];
      final end = booking['end_date'];
      if (dateStr.compareTo(start) >= 0 && dateStr.compareTo(end) <= 0) {
        final dogName = _dogs.firstWhere(
          (d) => d['id'] == booking['dog_id'],
          orElse: () => {'name': '?'},
        )['name'] as String;
        
        // Verifica se il cane ha avuto spostamenti in questo periodo
        final movimentiCane = _movimenti.where((m) {
          return m['cane_id'] == booking['dog_id'] &&
                 m['data_movimento'] <= dateStr;
        }).toList();

        String boxId = booking['box_id'];
        // Se ci sono spostamenti, prendi l'ultimo box di destinazione
        if (movimentiCane.isNotEmpty) {
          movimentiCane.sort((a, b) => a['data_movimento'].compareTo(b['data_movimento']));
          boxId = movimentiCane.last['box_destinazione'];
        }

        if (occupancy.containsKey(boxId)) {
          occupancy[boxId]!.add(dogName);
        }
      }
    }

    return occupancy;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final occupancy = _getOccupancyForDate(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📦 Box'),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                });
              },
            ),
            Text(
              ' ${DateFormat('dd/MM/yyyy').format(_selectedDate)} ',
              style: const TextStyle(fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {
                setState(() {
                  _selectedDate = _selectedDate.add(const Duration(days: 1));
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime.now();
                });
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _boxes.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'Nessun box configurato',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                      ),
                      child: const Text('Torna indietro'),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3 box per riga
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: _boxes.length,
                itemBuilder: (context, index) {
                  final box = _boxes[index];
                  final boxId = box['id'];
                  final dogsInBox = occupancy[boxId] ?? [];
                  final capacity = box['capacity'] ?? 2;
                  final isFull = dogsInBox.length >= capacity;

                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isFull 
                            ? Colors.red.shade50 
                            : (dogsInBox.isEmpty 
                                ? Colors.grey.shade50 
                                : Colors.green.shade50),
                        border: Border.all(
                          color: isFull 
                              ? Colors.red.shade300 
                              : (dogsInBox.isEmpty 
                                  ? Colors.grey.shade300 
                                  : Colors.green.shade300),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Numero del box
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.brown.shade800,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              box['name'] ?? 'Box',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          
                          // Nomi dei cani
                          if (dogsInBox.isNotEmpty)
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                itemCount: dogsInBox.length,
                                itemBuilder: (context, i) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      dogsInBox[i],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            const Expanded(
                              child: Center(
                                child: Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.grey,
                                  size: 32,
                                ),
                              ),
                            ),
                          
                          // Indicatore capienza
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isFull ? Colors.red.shade200 : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${dogsInBox.length}/${capacity}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isFull ? Colors.red.shade800 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
