import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking.dart';
import '../models/dog.dart';
import '../models/kennel_box.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _dogs = [];
  List<Map<String, dynamic>> _boxes = [];
  bool _isLoading = true;

  final SupabaseClient supabase = Supabase.instance.client;
  final Box<Booking> bookingBox = Hive.box<Booking>('bookings');
  final Box<Dog> dogBox = Hive.box<Dog>('dogs');
  final Box<KennelBox> boxBox = Hive.box<KennelBox>('kennel_boxes');

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final dogsResponse = await supabase.from('dogs').select('*');
      _dogs = List<Map<String, dynamic>>.from(dogsResponse);
      
      final boxesResponse = await supabase.from('boxes').select('*');
      _boxes = List<Map<String, dynamic>>.from(boxesResponse);
      
      final bookingsResponse = await supabase.from('bookings').select('*').order('start_date');
      _bookings = List<Map<String, dynamic>>.from(bookingsResponse);
      
      if (_dogs.isEmpty) {
        final localDogs = dogBox.values.toList();
        for (var dog in localDogs) {
          _dogs.add({
            'id': dog.supabaseId,
            'name': dog.name,
            'breed': dog.breed,
            'service_type': dog.serviceType,
          });
        }
      }
      
      if (_boxes.isEmpty) {
        final localBoxes = boxBox.values.toList();
        for (var box in localBoxes) {
          _boxes.add({
            'id': box.supabaseId,
            'name': box.name,
            'capacity': box.capacity,
          });
        }
      }
      
      if (_bookings.isEmpty) {
        final localBookings = bookingBox.values.toList();
        for (var booking in localBookings) {
          _bookings.add({
            'id': booking.supabaseId,
            'dog_id': booking.dogId,
            'box_id': booking.boxId,
            'start_date': booking.startDate.toIso8601String().split('T').first,
            'end_date': booking.endDate.toIso8601String().split('T').first,
            'notes': booking.notes,
          });
        }
      }
      
    } catch (e) {
      print('❌ Errore caricamento: $e');
    }
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _getBookingsForDate(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return _bookings.where((b) {
      final start = b['start_date'] ?? '';
      final end = b['end_date'] ?? '';
      return dateStr.compareTo(start) >= 0 && dateStr.compareTo(end) <= 0;
    }).toList();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================
  // 🔥 AGGIUNGI PRENOTAZIONE
  // ============================================================
  void _showAddBookingDialog({DateTime? selectedDate}) async {
    final date = selectedDate ?? DateTime.now();

    if (_dogs.isEmpty) {
      _showSnackBar('Aggiungi prima un cane nella sezione "Cani"');
      return;
    }
    if (_boxes.isEmpty) {
      _showSnackBar('Aggiungi prima un box nella sezione "Box"');
      return;
    }

    Map<String, dynamic>? selectedDog = _dogs.first;
    Map<String, dynamic>? selectedBox = _boxes.first;
    DateTime startDate = date;
    DateTime endDate = date;
    final notesController = TextEditingController();

    final existingBookings = _getBookingsForDate(date);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Nuova prenotazione'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (existingBookings.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📋 Box occupati il ${DateFormat('dd/MM/yyyy').format(date)}:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...existingBookings.map((b) {
                            final dog = _dogs.firstWhere(
                              (d) => d['id'] == b['dog_id'],
                              orElse: () => {'name': '?'},
                            );
                            final box = _boxes.firstWhere(
                              (bx) => bx['id'] == b['box_id'],
                              orElse: () => {'name': '?', 'capacity': 2},
                            );
                            final sameBoxBookings = existingBookings.where((eb) => eb['box_id'] == b['box_id']).toList();
                            final count = sameBoxBookings.length;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.pets, size: 14, color: Colors.orange[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${dog['name']} → ${box['name']} ($count/${box['capacity']})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: count >= (box['capacity'] ?? 2) ? Colors.red : Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedDog,
                    decoration: const InputDecoration(labelText: 'Cane *'),
                    items: _dogs.map((dog) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: dog,
                        child: Text(dog['name'] ?? ''),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedDog = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedBox,
                    decoration: const InputDecoration(labelText: 'Box *'),
                    items: _boxes.map((box) {
                      final bookingsInBox = existingBookings.where((b) => b['box_id'] == box['id']).toList();
                      final count = bookingsInBox.length;
                      final isFull = count >= (box['capacity'] ?? 2);

                      final dogNames = bookingsInBox.map((b) {
                        final dog = _dogs.firstWhere(
                          (d) => d['id'] == b['dog_id'],
                          orElse: () => {'name': '?'},
                        );
                        return dog['name'];
                      }).join(', ');

                      String label = box['name'] ?? '';
                      if (count > 0) {
                        label += ' 🐕 $dogNames ($count/${box['capacity']})';
                      } else {
                        label += ' (0/${box['capacity']})';
                      }

                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: box,
                        enabled: !isFull,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isFull ? Colors.red : (count > 0 ? Colors.orange : Colors.black),
                            fontWeight: isFull ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedBox = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  ListTile(
                    title: const Text('Data inizio'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(startDate)),
                    leading: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startDate = picked;
                          if (endDate.isBefore(startDate)) {
                            endDate = startDate;
                          }
                        });
                      }
                    },
                  ),

                  ListTile(
                    title: const Text('Data fine'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(endDate)),
                    leading: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: startDate,
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          endDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Note (opzionale)',
                      hintText: 'es. dieta speciale, terapia...',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedDog == null) {
                    _showSnackBar('Seleziona un cane');
                    return;
                  }
                  if (selectedBox == null) {
                    _showSnackBar('Seleziona un box');
                    return;
                  }
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('💾 Salva'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && selectedDog != null && selectedBox != null) {
      setState(() => _isLoading = true);
      try {
        final dogId = selectedDog!['id'] as String;
        final boxId = selectedBox!['id'] as String;

        final data = {
          'dog_id': dogId,
          'box_id': boxId,
          'start_date': DateFormat('yyyy-MM-dd').format(startDate),
          'end_date': DateFormat('yyyy-MM-dd').format(endDate),
          'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        };

        final resultInsert = await supabase.from('bookings').insert(data).select();
        final supabaseId = resultInsert[0]['id'] as String;
        
        final booking = Booking(
          supabaseId: supabaseId,
          dogId: dogId,
          boxId: boxId,
          startDate: startDate,
          endDate: endDate,
          notes: data['notes'],
          synced: true,
        );
        await bookingBox.add(booking);
        
        await _loadAllData();
        _showSnackBar('✅ Prenotazione salvata!');
        
      } catch (e) {
        _showSnackBar('❌ Errore: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // 🔥 ELIMINA PRENOTAZIONE
  // ============================================================
  void _deleteBooking(Map<String, dynamic> booking) async {
    final supabaseId = booking['id'] as String?;
    if (supabaseId == null) {
      final localBooking = bookingBox.values.firstWhere(
        (b) => b.supabaseId == supabaseId,
        orElse: () => Booking(dogId: '', boxId: '', startDate: DateTime.now(), endDate: DateTime.now()),
      );
      if (localBooking.dogId.isNotEmpty) await localBooking.delete();
      await _loadAllData();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina prenotazione'),
        content: const Text('Sei sicuro di voler eliminare questa prenotazione?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await supabase.from('bookings').delete().match({'id': supabaseId});
                final localBooking = bookingBox.values.firstWhere(
                  (b) => b.supabaseId == supabaseId,
                  orElse: () => Booking(dogId: '', boxId: '', startDate: DateTime.now(), endDate: DateTime.now()),
                );
                if (localBooking.dogId.isNotEmpty) await localBooking.delete();
                await _loadAllData();
                _showSnackBar('✅ Prenotazione eliminata');
                Navigator.pop(context);
              } catch (e) {
                _showSnackBar('❌ Errore: $e');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 MODIFICA PRENOTAZIONE
  // ============================================================
  void _showEditBookingDialog(Map<String, dynamic> booking) async {
    final currentDog = _dogs.firstWhere(
      (d) => d['id'] == booking['dog_id'],
      orElse: () => {'name': 'Cane sconosciuto', 'id': ''},
    );
    final currentBox = _boxes.firstWhere(
      (b) => b['id'] == booking['box_id'],
      orElse: () => {'name': 'Box sconosciuto', 'id': ''},
    );

    Map<String, dynamic>? selectedDog = currentDog;
    Map<String, dynamic>? selectedBox = currentBox;
    DateTime startDate = DateTime.parse(booking['start_date']);
    DateTime endDate = DateTime.parse(booking['end_date']);
    final notesController = TextEditingController(text: booking['notes'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('✏️ Modifica prenotazione'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🐕 ${currentDog['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('📦 Box attuale: ${currentBox['name']}'),
                        Text('📅 ${booking['start_date']} → ${booking['end_date']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedDog,
                    decoration: const InputDecoration(labelText: 'Cane *'),
                    items: _dogs.map((dog) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: dog,
                        child: Text(dog['name'] ?? ''),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedDog = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedBox,
                    decoration: const InputDecoration(labelText: 'Box *'),
                    items: _boxes.map((box) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: box,
                        child: Text(box['name'] ?? ''),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedBox = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  ListTile(
                    title: const Text('Data inizio'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(startDate)),
                    leading: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startDate = picked;
                          if (endDate.isBefore(startDate)) {
                            endDate = startDate;
                          }
                        });
                      }
                    },
                  ),

                  ListTile(
                    title: const Text('Data fine'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(endDate)),
                    leading: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: startDate,
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          endDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Note (opzionale)',
                      hintText: 'es. dieta speciale, terapia...',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedDog == null) {
                    _showSnackBar('Seleziona un cane');
                    return;
                  }
                  if (selectedBox == null) {
                    _showSnackBar('Seleziona un box');
                    return;
                  }
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('💾 Salva modifiche'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && selectedDog != null && selectedBox != null) {
      setState(() => _isLoading = true);
      try {
        final data = {
          'dog_id': selectedDog['id'],
          'box_id': selectedBox['id'],
          'start_date': DateFormat('yyyy-MM-dd').format(startDate),
          'end_date': DateFormat('yyyy-MM-dd').format(endDate),
          'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        };

        await supabase.from('bookings').update(data).match({'id': booking['id']});
        
        final localBooking = bookingBox.values.firstWhere(
          (b) => b.supabaseId == booking['id'],
          orElse: () => Booking(dogId: '', boxId: '', startDate: DateTime.now(), endDate: DateTime.now()),
        );
        if (localBooking.dogId.isNotEmpty) {
          localBooking.dogId = data['dog_id'] as String;
          localBooking.boxId = data['box_id'] as String;
          localBooking.startDate = startDate;
          localBooking.endDate = endDate;
          localBooking.notes = data['notes'];
          localBooking.synced = true;
          await localBooking.save();
        }

        await _loadAllData();
        _showSnackBar('✅ Prenotazione modificata!');
      } catch (e) {
        _showSnackBar('❌ Errore: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // 🔥 BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Raggruppa le prenotazioni per data (per la lista)
    final Map<DateTime, List<Map<String, dynamic>>> bookingsByDay = {};
    for (var booking in _bookings) {
      final start = DateTime.parse(booking['start_date'] as String);
      final end = DateTime.parse(booking['end_date'] as String);
      var current = start;
      
      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        final key = DateTime(current.year, current.month, current.day);
        if (!bookingsByDay.containsKey(key)) {
          bookingsByDay[key] = [];
        }
        bookingsByDay[key]!.add(booking);
        current = current.add(const Duration(days: 1));
      }
    }

    // Raggruppa le prenotazioni per data (per le barre)
    final Map<DateTime, List<Map<String, dynamic>>> bookingsForDay = {};
    for (var booking in _bookings) {
      final start = DateTime.parse(booking['start_date'] as String);
      final end = DateTime.parse(booking['end_date'] as String);
      var current = start;
      
      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        final key = DateTime(current.year, current.month, current.day);
        if (!bookingsForDay.containsKey(key)) {
          bookingsForDay[key] = [];
        }
        bookingsForDay[key]!.add(booking);
        current = current.add(const Duration(days: 1));
      }
    }

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onDayLongPressed: (selectedDay, focusedDay) {
            _showAddBookingDialog(selectedDate: selectedDay);
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          // 🔥 CALENDAR BUILDERS PER LE BARRE
          calendarBuilders: CalendarBuilders(
            dayBuilder: (context, date, _) {
              final dayBookings = bookingsForDay[date] ?? [];
              
              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSameDay(date, _selectedDay) 
                      ? Colors.brown.withOpacity(0.2) 
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Numero del giorno
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontWeight: isSameDay(date, _selectedDay) 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                        color: date.weekday == 6 || date.weekday == 7
                            ? Colors.red[400]
                            : null,
                      ),
                    ),
                    // 🔥 BARRE DELLE PRENOTAZIONI
                    if (dayBookings.isNotEmpty)
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dayBookings.length > 2 ? 2 : dayBookings.length,
                          itemBuilder: (context, index) {
                            final booking = dayBookings[index];
                            final dog = _dogs.firstWhere(
                              (d) => d['id'] == booking['dog_id'],
                              orElse: () => {'name': '?', 'service_type': 'pensione'},
                            );
                            final color = dog['service_type'] == 'asilo' 
                                ? Colors.orange 
                                : Colors.blue;
                            
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                dog['name'] ?? '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          },
                        ),
                      ),
                    if (dayBookings.length > 2)
                      Text(
                        '+${dayBookings.length - 2}',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          calendarStyle: CalendarStyle(
            weekendTextStyle: TextStyle(color: Colors.red[400]),
            selectedDecoration: BoxDecoration(
              color: Colors.brown.withOpacity(0.2),
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(8),
            ),
            todayDecoration: BoxDecoration(
              color: Colors.brown[100],
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(8),
            ),
            markerDecoration: const BoxDecoration(
              color: Colors.brown,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextFormatter: (date, locale) {
              return DateFormat('MMMM yyyy', 'it').format(date);
            },
          ),
          locale: 'it_IT',
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildBookingsList(bookingsByDay),
        ),
      ],
    );
  }

  // ============================================================
  // 🔥 LISTA PRENOTAZIONI DEL GIORNO
  // ============================================================
  Widget _buildBookingsList(Map<DateTime, List<Map<String, dynamic>>> bookingsByDay) {
    final key = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final dayBookings = bookingsByDay[key] ?? [];

    if (dayBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nessuna prenotazione per questa data',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            if (_boxes.isNotEmpty && _dogs.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () => _showAddBookingDialog(selectedDate: _selectedDay),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('➕ Aggiungi prenotazione'),
              ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        ...dayBookings.map((booking) {
          final dog = _dogs.firstWhere(
            (d) => d['id'] == booking['dog_id'],
            orElse: () => {'name': 'Cane sconosciuto', 'service_type': 'pensione'},
          );
          final box = _boxes.firstWhere(
            (b) => b['id'] == booking['box_id'],
            orElse: () => {'name': 'Box sconosciuto', 'capacity': 2},
          );

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.brown[100],
                child: const Icon(Icons.pets, color: Colors.brown),
              ),
              title: Text(dog['name'] ?? ''),
              subtitle: Text(
                '${box['name']} • ${DateFormat('dd/MM/yyyy').format(DateTime.parse(booking['start_date'] as String))} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(booking['end_date'] as String))}${booking['notes'] != null ? '\n📝 ${booking['notes']}' : ''}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔥 PULSANTE MODIFICA
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showEditBookingDialog(booking),
                    tooltip: 'Modifica prenotazione',
                  ),
                  // PULSANTE ELIMINA
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteBooking(booking),
                  ),
                ],
              ),
            ),
          );
        }).toList(),

        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => _showAddBookingDialog(selectedDate: _selectedDay),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add),
            label: const Text('➕ Aggiungi altra prenotazione'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
