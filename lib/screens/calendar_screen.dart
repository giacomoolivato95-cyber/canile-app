import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  Map<DateTime, List<Booking>> _bookingsByDay = {};

  final Box<Booking> bookingBox = Hive.box<Booking>('bookings');
  final Box<Dog> dogBox = Hive.box<Dog>('dogs');
  final Box<KennelBox> boxBox = Hive.box<KennelBox>('kennel_boxes');

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  void _loadBookings() {
    final bookings = bookingBox.values.toList();

    final Map<DateTime, List<Booking>> grouped = {};
    for (var booking in bookings) {
      final start = DateTime(booking.startDate.year, booking.startDate.month, booking.startDate.day);
      final end = DateTime(booking.endDate.year, booking.endDate.month, booking.endDate.day);

      for (var date = start;
          date.isBefore(end) || date.isAtSameMomentAs(end);
          date = date.add(const Duration(days: 1))) {
        final key = DateTime(date.year, date.month, date.day);
        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }
        grouped[key]!.add(booking);
      }
    }

    setState(() {
      _bookingsByDay = grouped;
    });
  }

  // Mostra il dialog per aggiungere una prenotazione
  void _showAddBookingDialog({DateTime? selectedDate}) async {
    final date = selectedDate ?? DateTime.now();

    if (dogBox.values.isEmpty) {
      _showSnackBar('Aggiungi prima un cane nella sezione "Cani"');
      return;
    }
    if (boxBox.values.isEmpty) {
      _showSnackBar('Aggiungi prima un box nella sezione "Box"');
      return;
    }

    Dog? selectedDog = dogBox.values.first;
    KennelBox? selectedBox = boxBox.values.first;
    DateTime startDate = date;
    DateTime endDate = date;
    final notesController = TextEditingController();

    // Trova le prenotazioni per la data selezionata
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
                  // Mostra i box già occupati
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
                            final dog = dogBox.values.firstWhere(
                              (d) => d.supabaseId == b.dogId,
                              orElse: () => Dog(name: '?'),
                            );
                            final box = boxBox.values.firstWhere(
                              (bx) => bx.supabaseId == b.boxId,
                              orElse: () => KennelBox(name: '?', capacity: 2),
                            );
                            // Conta quanti cani sono nello stesso box
                            final sameBoxBookings = existingBookings.where((eb) => eb.boxId == b.boxId).toList();
                            final count = sameBoxBookings.length;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.pets, size: 14, color: Colors.orange[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${dog.name} → ${box.name} (${count}/${box.capacity})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: count >= box.capacity ? Colors.red : Colors.orange[700],
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

                  // Selezione cane
                  DropdownButtonFormField<Dog>(
                    value: selectedDog,
                    decoration: const InputDecoration(labelText: 'Cane *'),
                    items: dogBox.values.map((dog) {
                      return DropdownMenuItem<Dog>(
                        value: dog,
                        child: Text(dog.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedDog = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Selezione box con info
                  DropdownButtonFormField<KennelBox>(
                    value: selectedBox,
                    decoration: const InputDecoration(labelText: 'Box *'),
                    items: boxBox.values.map((box) {
                      // Trova i cani già nel box per la data selezionata
                      final bookingsInBox = existingBookings.where((b) => b.boxId == box.supabaseId).toList();
                      final count = bookingsInBox.length;
                      final isFull = count >= box.capacity;

                      // Nomi dei cani già presenti
                      final dogNames = bookingsInBox.map((b) {
                        final dog = dogBox.values.firstWhere(
                          (d) => d.supabaseId == b.dogId,
                          orElse: () => Dog(name: '?'),
                        );
                        return dog.name;
                      }).join(', ');

                      // Trova i box adiacenti
                      final boxList = boxBox.values.toList();
                      final currentIndex = boxList.indexOf(box);
                      final prevBox = currentIndex > 0 ? boxList[currentIndex - 1] : null;
                      final nextBox = currentIndex < boxList.length - 1 ? boxList[currentIndex + 1] : null;

                      // Trova chi è nei box adiacenti
                      String? prevOccupant;
                      if (prevBox != null) {
                        final prevBookings = existingBookings.where((b) => b.boxId == prevBox.supabaseId).toList();
                        if (prevBookings.isNotEmpty) {
                          final names = prevBookings.map((b) {
                            final dog = dogBox.values.firstWhere(
                              (d) => d.supabaseId == b.dogId,
                              orElse: () => Dog(name: '?'),
                            );
                            return dog.name;
                          }).join(', ');
                          prevOccupant = names;
                        }
                      }

                      String? nextOccupant;
                      if (nextBox != null) {
                        final nextBookings = existingBookings.where((b) => b.boxId == nextBox.supabaseId).toList();
                        if (nextBookings.isNotEmpty) {
                          final names = nextBookings.map((b) {
                            final dog = dogBox.values.firstWhere(
                              (d) => d.supabaseId == b.dogId,
                              orElse: () => Dog(name: '?'),
                            );
                            return dog.name;
                          }).join(', ');
                          nextOccupant = names;
                        }
                      }

                      // Costruisce il testo del dropdown
                      String label = box.name;
                      if (count > 0) {
                        label += ' 🐕 $dogNames ($count/${box.capacity})';
                      } else {
                        label += ' (0/${box.capacity})';
                      }
                      if (prevOccupant != null) {
                        label += ' ⬅️ $prevOccupant';
                      }
                      if (nextOccupant != null) {
                        label += ' ➡️ $nextOccupant';
                      }

                      return DropdownMenuItem<KennelBox>(
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

                  // Data inizio
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

                  // Data fine
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

                  // Note
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
      // Verifica la capienza del box
      final capacityCheck = _checkBoxCapacity(selectedBox!.supabaseId!, startDate, endDate);
      if (capacityCheck != null) {
        _showSnackBar('⚠️ Box pieno: $capacityCheck');
        return;
      }

      final booking = Booking(
        dogId: selectedDog!.supabaseId ?? '',
        boxId: selectedBox!.supabaseId ?? '',
        startDate: startDate,
        endDate: endDate,
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        synced: false,
      );
      bookingBox.add(booking);
      _loadBookings();
      _showSnackBar('✅ Prenotazione aggiunta!');
    }
  }

  // Verifica la capienza del box per un periodo
  String? _checkBoxCapacity(String boxId, DateTime start, DateTime end) {
    final box = boxBox.values.firstWhere(
      (b) => b.supabaseId == boxId,
      orElse: () => KennelBox(name: '?', capacity: 2),
    );
    
    final bookings = bookingBox.values.toList();
    int count = 0;
    for (var booking in bookings) {
      if (booking.boxId != boxId) continue;
      // Controlla se i periodi si sovrappongono
      if (!(end.isBefore(booking.startDate) || start.isAfter(booking.endDate))) {
        count++;
      }
    }
    
    if (count >= box.capacity) {
      return 'Capienza massima (${box.capacity} cani) raggiunta';
    }
    return null;
  }

  // Ottiene le prenotazioni per una data specifica
  List<Booking> _getBookingsForDate(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return _bookingsByDay[key] ?? [];
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _deleteBooking(Booking booking) {
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
            onPressed: () {
              booking.delete();
              _loadBookings();
              Navigator.pop(context);
              _showSnackBar('Prenotazione eliminata');
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          eventLoader: (day) {
            final key = DateTime(day.year, day.month, day.day);
            return _bookingsByDay[key] ?? [];
          },
          calendarStyle: CalendarStyle(
            weekendTextStyle: TextStyle(color: Colors.red[400]),
            selectedDecoration: BoxDecoration(
              color: Colors.brown,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Colors.brown[100],
              shape: BoxShape.circle,
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
          child: _buildBookingsList(),
        ),
      ],
    );
  }

  Widget _buildBookingsList() {
    final key = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final dayBookings = _bookingsByDay[key] ?? [];
    
    // Raggruppa per box con conteggio
    final Map<String, List<Booking>> bookingsByBox = {};
    for (var booking in dayBookings) {
      if (!bookingsByBox.containsKey(booking.boxId)) {
        bookingsByBox[booking.boxId] = [];
      }
      bookingsByBox[booking.boxId]!.add(booking);
    }

    // Box liberi (con capienza residua)
    final availableBoxes = boxBox.values.where((box) {
      final boxBookings = dayBookings.where((b) => b.boxId == box.supabaseId).toList();
      return boxBookings.length < box.capacity;
    }).toList();

    if (dayBookings.isEmpty && availableBoxes.isEmpty) {
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
            if (boxBox.values.isNotEmpty && dogBox.values.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () => _showAddBookingDialog(selectedDate: _selectedDay),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi prenotazione'),
              ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // Mostra le prenotazioni esistenti raggruppate per box
        if (dayBookings.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '📋 Prenotazioni del giorno:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ...bookingsByBox.entries.map((entry) {
            final box = boxBox.values.firstWhere(
              (b) => b.supabaseId == entry.key,
              orElse: () => KennelBox(name: 'Box sconosciuto', capacity: 2),
            );
            final bookings = entry.value;
            
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2, color: Colors.brown),
                        const SizedBox(width: 8),
                        Text(
                          box.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Chip(
                          label: Text(
                            '${bookings.length}/${box.capacity}',
                            style: TextStyle(
                              color: bookings.length >= box.capacity ? Colors.red : Colors.green,
                            ),
                          ),
                          backgroundColor: Colors.grey[200],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...bookings.map((booking) {
                      final dog = dogBox.values.firstWhere(
                        (d) => d.supabaseId == booking.dogId,
                        orElse: () => Dog(name: 'Cane sconosciuto'),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.pets, size: 16, color: Colors.brown),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${dog.name} • ${booking.formattedStart} - ${booking.formattedEnd}${booking.notes != null ? ' 📝 ${booking.notes}' : ''}',
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () => _deleteBooking(booking),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            );
          }).toList(),
        ],

        // Mostra i box con spazio disponibile
        if (availableBoxes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '✅ Box con spazio disponibile:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableBoxes.map((box) {
              final boxBookings = dayBookings.where((b) => b.boxId == box.supabaseId).toList();
              final free = box.capacity - boxBookings.length;
              return Chip(
                label: Text('${box.name} (+$free)'),
                backgroundColor: Colors.green[50],
                avatar: const Icon(Icons.check_circle, color: Colors.green, size: 16),
              );
            }).toList(),
          ),
        ],

        // Bottone per aggiungere prenotazione (sempre visibile)
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
      ],
    );
  }
}