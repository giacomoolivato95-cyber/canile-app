import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/dog.dart';

class DogsScreen extends StatefulWidget {
  const DogsScreen({super.key});

  @override
  State<DogsScreen> createState() => _DogsScreenState();
}

class _DogsScreenState extends State<DogsScreen> {
  final Box<Dog> dogBox = Hive.box<Dog>('dogs');
  String? _selectedServiceType = 'pensione';

  void _showAddDogDialog([Dog? dogToEdit]) async {
    final isEditing = dogToEdit != null;
    final nameController = TextEditingController(text: dogToEdit?.name ?? '');
    final breedController = TextEditingController(text: dogToEdit?.breed ?? '');
    final ownerController = TextEditingController(text: dogToEdit?.owner ?? '');
    final phoneController = TextEditingController(text: dogToEdit?.phone ?? '');
    final notesController = TextEditingController(text: dogToEdit?.notes ?? '');
    
    // Valore iniziale per il tipo servizio
    String? selectedServiceType = dogToEdit?.serviceType ?? 'pensione';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Modifica cane' : 'Nuovo cane'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nome
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome *'),
                  ),
                  const SizedBox(height: 8),
                  
                  // RAZZA (NUOVO)
                  TextField(
                    controller: breedController,
                    decoration: const InputDecoration(labelText: 'Razza'),
                  ),
                  const SizedBox(height: 8),
                  
                  // TIPO SERVIZIO (ASILO/PENSIONE) con colori
                  DropdownButtonFormField<String>(
                    value: selectedServiceType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo servizio *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pensione',
                        child: Row(
                          children: [
                            Icon(Icons.home, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('🏠 Pensione'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'asilo',
                        child: Row(
                          children: [
                            Icon(Icons.school, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('🎨 Asilo'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedServiceType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  
                  // Proprietario
                  TextField(
                    controller: ownerController,
                    decoration: const InputDecoration(labelText: 'Proprietario'),
                  ),
                  const SizedBox(height: 8),
                  
                  // Telefono
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Telefono'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  
                  // Note
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Note'),
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
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Il nome è obbligatorio')),
                    );
                    return;
                  }
                  if (selectedServiceType == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Seleziona il tipo servizio')),
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(isEditing ? '💾 Salva' : '➕ Aggiungi'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      if (isEditing) {
        dogToEdit!.name = nameController.text.trim();
        dogToEdit.breed = breedController.text.trim().isEmpty ? null : breedController.text.trim();
        dogToEdit.serviceType = selectedServiceType!;
        dogToEdit.owner = ownerController.text.trim().isEmpty ? null : ownerController.text.trim();
        dogToEdit.phone = phoneController.text.trim().isEmpty ? null : phoneController.text.trim();
        dogToEdit.notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();
        dogToEdit.save();
      } else {
        final dog = Dog(
          name: nameController.text.trim(),
          breed: breedController.text.trim().isEmpty ? null : breedController.text.trim(),
          serviceType: selectedServiceType!,
          owner: ownerController.text.trim().isEmpty ? null : ownerController.text.trim(),
          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
          synced: false,
        );
        dogBox.add(dog);
      }
      setState(() {});
    }
  }

  void _deleteDog(Dog dog) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina cane'),
        content: Text('Eliminare ${dog.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              dog.delete();
              setState(() {});
              Navigator.pop(context);
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
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDogDialog,
        backgroundColor: Colors.brown,
        child: const Icon(Icons.add),
      ),
      body: dogBox.values.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Nessun cane registrato',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showAddDogDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('➕ Aggiungi cane'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: dogBox.values.length,
              itemBuilder: (context, index) {
                final dog = dogBox.values.toList()[index];
                
                // Colore diverso per tipo servizio
                final Color cardColor = dog.serviceType == 'asilo' 
                    ? Colors.orange.shade50 
                    : Colors.blue.shade50;
                
                final Color iconColor = dog.serviceType == 'asilo' 
                    ? Colors.orange 
                    : Colors.blue;
                
                final String serviceLabel = dog.serviceType == 'asilo' 
                    ? '🎨 Asilo' 
                    : '🏠 Pensione';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: cardColor,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withOpacity(0.2),
                      child: Text(
                        dog.name[0].toUpperCase(),
                        style: TextStyle(color: iconColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      dog.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dog.breed != null) Text('🐕 ${dog.breed}'),
                        Text(
                          '${dog.owner ?? 'Proprietario non indicato'}${dog.phone != null ? ' • ${dog.phone}' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            serviceLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: iconColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showAddDogDialog(dog),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _deleteDog(dog),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}