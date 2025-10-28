import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditBarangPage extends StatefulWidget {
  const EditBarangPage({super.key});

  @override
  State<EditBarangPage> createState() => _EditBarangPageState();
}

class _EditBarangPageState extends State<EditBarangPage> {
  final _formKey = GlobalKey<FormState>();

  final _namaController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _tanggalKeluarController = TextEditingController();
  final _tanggalRusakController = TextEditingController();
  final _noInventarisController = TextEditingController();
  final _snController = TextEditingController();
  final _keteranganController = TextEditingController();
  String? _selectedJenis;
  String? _status;
  late String docId;

  final List<String> _jenisList = [
    'Printer',
    'PC',
    'Switch',
    'CCTV',
    'Monitor',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    docId = args['id'];
    _namaController.text = args['nama'] ?? '';
    _selectedJenis = args['jenis'] ?? '';
    _noInventarisController.text = args['no_inventaris'] ?? '';
    _snController.text = args['sn'] ?? '';
    _keteranganController.text = args['keterangan'] ?? '';
    _status = args['status'] ?? '';

    // Tanggal Masuk
    final tanggalMasuk = args['tanggal_masuk'];
    if (tanggalMasuk is Timestamp) {
      final d = tanggalMasuk.toDate();
      _tanggalController.text =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    } else if (tanggalMasuk is String) {
      _tanggalController.text = tanggalMasuk;
    }

    // Tanggal Keluar
    final tanggalKeluar = args['tanggal_keluar'];
    if (tanggalKeluar is Timestamp) {
      final d = tanggalKeluar.toDate();
      _tanggalKeluarController.text =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    } else if (tanggalKeluar is String) {
      _tanggalKeluarController.text = tanggalKeluar;
    }

    // Tanggal Rusak
    final tanggalRusak = args['tanggal_rusak'];
    if (tanggalRusak is Timestamp) {
      final d = tanggalRusak.toDate();
      _tanggalRusakController.text =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    } else if (tanggalRusak is String) {
      _tanggalRusakController.text = tanggalRusak;
    }

    if (_status == 'rusak') _tanggalKeluarController.clear();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _tanggalController.dispose();
    _tanggalKeluarController.dispose();
    _tanggalRusakController.dispose();
    _noInventarisController.dispose();
    _snController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initial = DateTime.parse(controller.text);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _updateData() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final Map<String, dynamic> updateData = {
        'nama': _namaController.text.trim(),
        'jenis': _selectedJenis ?? '',
        'no_inventaris': _noInventarisController.text.trim(),
        'sn': _snController.text.trim(),
        'keterangan': _keteranganController.text.trim(),
        'status': _status ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_tanggalController.text.trim().isNotEmpty) {
        updateData['tanggal_masuk'] =
            Timestamp.fromDate(DateTime.parse(_tanggalController.text.trim()));
      }

      if (_status == 'keluar') {
        if (_tanggalKeluarController.text.trim().isNotEmpty) {
          updateData['tanggal_keluar'] = Timestamp.fromDate(
              DateTime.parse(_tanggalKeluarController.text.trim()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Tanggal keluar wajib diisi untuk status KELUAR')));
          return;
        }
        updateData['tanggal_rusak'] = FieldValue.delete();
      } else if (_status == 'rusak') {
        if (_tanggalRusakController.text.trim().isNotEmpty) {
          updateData['tanggal_rusak'] = Timestamp.fromDate(
              DateTime.parse(_tanggalRusakController.text.trim()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Tanggal rusak wajib diisi untuk status RUSAK')));
          return;
        }
        updateData['tanggal_keluar'] = FieldValue.delete();
      } else {
        updateData['tanggal_keluar'] = FieldValue.delete();
        updateData['tanggal_rusak'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('items')
          .doc(docId)
          .update(updateData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil diupdate')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal update data: $e')));
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w500),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Colors.teal.shade700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFB),
      appBar: AppBar(
        backgroundColor: mainColor,
        elevation: 2,
        title: const Text(
          'Edit Barang',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Nama & Model
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _namaController,
                                    decoration: _inputDecoration('Nama Barang'),
                                    validator: (value) => value == null ||
                                            value.isEmpty
                                        ? 'Wajib diisi'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true, // allow using full available width
                                    value: _selectedJenis,
                                    decoration: _inputDecoration('Model'),
                                    iconSize: 20,
                                    items: _jenisList.map((jenis) {
                                      return DropdownMenuItem(
                                        value: jenis,
                                        child: Text(jenis, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedJenis = val),
                                    validator: (v) => v == null || v.isEmpty ? 'Pilih model' : null,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Tanggal Masuk & No Inventaris
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _tanggalController,
                                    readOnly: true,
                                    decoration:
                                        _inputDecoration('Tanggal Masuk'),
                                    onTap: () => _pickDate(_tanggalController),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Wajib diisi'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _noInventarisController,
                                    decoration:
                                        _inputDecoration('No. Inventaris'),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // SN & Status
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _snController,
                                    decoration:
                                        _inputDecoration('Serial Number (SN)'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _status,
                                    iconSize: 20,
                                    items: ['masuk', 'keluar', 'rusak']
                                        .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s.toUpperCase(), overflow: TextOverflow.ellipsis)))
                                        .toList(),
                                    onChanged: (v) {
                                      setState(() {
                                        _status = v;
                                        if (v == 'rusak') {
                                          _tanggalKeluarController.clear();
                                        } else if (v == 'keluar') {
                                          _tanggalRusakController.clear();
                                        } else {
                                          _tanggalKeluarController.clear();
                                          _tanggalRusakController.clear();
                                        }
                                      });
                                    },
                                    decoration: _inputDecoration('Status'),
                                    validator: (v) => v == null ? 'Pilih status' : null,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Conditional date fields
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _status == 'keluar'
                                  ? Column(
                                      key: const ValueKey('keluar'),
                                      children: [
                                        TextFormField(
                                          controller: _tanggalKeluarController,
                                          readOnly: true,
                                          decoration: _inputDecoration(
                                              'Tanggal Keluar'),
                                          onTap: () =>
                                              _pickDate(_tanggalKeluarController),
                                          validator: (v) {
                                            if (_status == 'keluar' &&
                                                (v == null ||
                                                    v.trim().isEmpty)) {
                                              return 'Wajib diisi untuk status KELUAR';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    )
                                  : _status == 'rusak'
                                      ? Column(
                                          key: const ValueKey('rusak'),
                                          children: [
                                            TextFormField(
                                              controller:
                                                  _tanggalRusakController,
                                              readOnly: true,
                                              decoration: _inputDecoration(
                                                  'Tanggal Rusak'),
                                              onTap: () => _pickDate(
                                                  _tanggalRusakController),
                                              validator: (v) {
                                                if (_status == 'rusak' &&
                                                    (v == null ||
                                                        v.trim().isEmpty)) {
                                                  return 'Wajib diisi untuk status RUSAK';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                        )
                                      : const SizedBox.shrink(),
                            ),

                            TextFormField(
                              controller: _keteranganController,
                              decoration: _inputDecoration('Keterangan'),
                              maxLines: 2,
                            ),

                            const Spacer(),

                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _updateData,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Simpan Perubahan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mainColor,
                                foregroundColor: Colors.white,
                                minimumSize:
                                    const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Batal'),
                              style: OutlinedButton.styleFrom(
                                minimumSize:
                                    const Size(double.infinity, 50),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
