import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../actions/native_action_client.dart';
import '../contacts/favorite_contacts_repository.dart';

class FavoriteContactsPage extends StatefulWidget {
  const FavoriteContactsPage({super.key, required this.repository});

  final FavoriteContactsRepository repository;

  @override
  State<FavoriteContactsPage> createState() => _FavoriteContactsPageState();
}

class _FavoriteContactsPageState extends State<FavoriteContactsPage> {
  static const ink = Color(0xFF242521);
  static const muted = Color(0xFF777971);
  static const line = Color(0xFFE9E8E2);
  final NativeActionClient _native = NativeActionClient();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _aliases = TextEditingController();
  List<Map<String, String>> _deviceContacts = [];
  FavoriteContact? _editingContact;
  bool _showEditor = false;
  bool _showBrowser = false;

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _phone.dispose();
    _aliases.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    final picked = await _native.pickContact();
    if (picked['status'] == 'selected') {
      final saved = await _savePicked(
        picked['name']?.toString() ?? '',
        picked['phone']?.toString() ?? '',
      );
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'That contact did not include a usable name and number.',
            ),
          ),
        );
      }
    } else if (picked['status'] == 'unavailable') {
      await _showContactFallback();
    } else if (picked['status'] == 'cancelled') {
      return;
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            picked['error']?.toString() ??
                picked['errorMessage']?.toString() ??
                'Could not open the contact picker. Try the in-app contact list.',
          ),
          action: SnackBarAction(
            label: 'Browse',
            onPressed: _showContactFallback,
          ),
        ),
      );
    }
  }

  Future<bool> _savePicked(String name, String phone) async {
    if (name.trim().isEmpty || phone.trim().isEmpty) return false;
    await widget.repository.save(
      FavoriteContact(displayName: name.trim(), phoneNumber: phone.trim()),
    );
    if (mounted) setState(() {});
    return true;
  }

  Future<void> _showContactFallback() async {
    final permission = await Permission.contacts.request();
    if (!permission.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allow contacts access to choose a pinned contact.'),
          ),
        );
      }
      return;
    }
    final lookup = await _native.searchContacts('');
    final contacts = (lookup['contacts'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (contact) => {
            'name': contact['name']?.toString() ?? '',
            'phone': contact['phone']?.toString() ?? '',
          },
        )
        .where(
          (contact) =>
              (contact['name'] ?? '').isNotEmpty &&
              (contact['phone'] ?? '').isNotEmpty,
        )
        .toList();
    if (!mounted) return;
    setState(() {
      _deviceContacts = contacts;
      _search.clear();
      _showBrowser = true;
    });
  }

  void _edit([FavoriteContact? existing]) {
    _editingContact = existing;
    _name.text = existing?.displayName ?? '';
    _phone.text = existing?.phoneNumber ?? '';
    _aliases.text = existing?.aliases.join(', ') ?? '';
    setState(() {
      _showEditor = true;
      _showBrowser = false;
    });
  }

  Future<void> _saveEditor() async {
    final displayName = _name.text.trim();
    final phoneNumber = _phone.text.trim();
    if (displayName.isEmpty || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter both a contact name and phone number.'),
        ),
      );
      return;
    }
    await widget.repository.save(
      FavoriteContact(
        displayName: displayName,
        phoneNumber: phoneNumber,
        aliases: _aliases.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(),
      ),
      previousPhoneNumber: _editingContact?.phoneNumber,
    );
    if (mounted) {
      setState(() => _showEditor = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$displayName saved to pinned contacts.')),
      );
    }
  }

  Future<void> _saveFromBrowser(Map<String, String> contact) async {
    final saved = await _savePicked(
      contact['name'] ?? '',
      contact['phone'] ?? '',
    );
    if (!mounted) return;
    setState(() => _showBrowser = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? '${contact['name']} added to pinned contacts.'
              : 'This contact does not have a usable phone number.',
        ),
      ),
    );
  }

  Future<void> _delete(FavoriteContact contact) async {
    await widget.repository.delete(
      contact.displayName,
      phoneNumber: contact.phoneNumber,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final contacts = widget.repository.getAll();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7F2),
        title: const Text('Pinned contacts'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          const Text(
            'Names and aliases stay on this phone.',
            style: TextStyle(color: muted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          if (_showEditor) ...[
            _inlinePanel(
              title: _editingContact == null
                  ? 'Add a pinned contact'
                  : 'Edit pinned contact',
              children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                TextField(
                  controller: _aliases,
                  decoration: const InputDecoration(
                    labelText: 'Spoken aliases',
                    hintText: 'Comma separated',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _showEditor = false),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _saveEditor,
                      icon: const Icon(Icons.check),
                      label: const Text('Save contact'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_showBrowser) ...[
            _inlinePanel(
              title: 'Choose from your contacts',
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search name or number',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: Builder(
                    builder: (context) {
                      final needle = _search.text.trim().toLowerCase();
                      final visible = _deviceContacts
                          .where(
                            (contact) =>
                                (contact['name'] ?? '').toLowerCase().contains(
                                  needle,
                                ) ||
                                (contact['phone'] ?? '').contains(needle),
                          )
                          .toList();
                      if (visible.isEmpty)
                        return const Center(child: Text('No contacts found.'));
                      return ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final contact = visible[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(contact['name'] ?? ''),
                            subtitle: Text(contact['phone'] ?? ''),
                            trailing: const Icon(Icons.add_circle_outline),
                            onTap: () => _saveFromBrowser(contact),
                          );
                        },
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _showBrowser = false),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          for (final contact in contacts)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.displayName,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit ${contact.displayName}',
                        onPressed: () => _edit(contact),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Remove ${contact.displayName}',
                        onPressed: () => _delete(contact),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    contact.phoneNumber,
                    style: const TextStyle(color: muted),
                  ),
                  if (contact.aliases.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      contact.aliases.join(' · '),
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _pickContact,
              icon: const Icon(Icons.contacts_outlined),
              label: const Text('Pick from contacts'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add manually'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlinePanel({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
