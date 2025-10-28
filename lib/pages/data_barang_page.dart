import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'rekap_barang_page.dart';

class DataBarangPage extends StatefulWidget {
  const DataBarangPage({super.key});

  @override
  State<DataBarangPage> createState() => _DataBarangPageState();
}

class _DataBarangPageState extends State<DataBarangPage> {
  String _search = '';
  String _selectedStatus = 'Semua';
  String _selectedJenis = 'Semua'; // Tambahkan ini

  final List<String> _statusList = [
    'Semua',
    'Masuk',
    'Keluar',
    'Rusak',
  ];

  final List<String> _jenisList = [ // Tambahkan ini
    'Semua',
    'Printer',
    'PC',
    'Switch',
    'CCTV',
    'Monitor',
  ];

  // --- ADDED FOR AUTOCOMPLETE ---
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, String>> _suggestions = []; // each item: {'nama':..., 'sn':..., 'no_inventaris':..., 'id':...}
  bool _showSuggestions = false;
  // --- END ADDED ---

  int _rowsPerPage = 5;
  int _currentPage = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final mainColor = Colors.teal.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Barang'),
        backgroundColor: mainColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Landscape',
            icon: const Icon(Icons.screen_rotation_alt),
            onPressed: () {
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]);
            },
          ),
          IconButton(
            tooltip: 'Portrait',
            icon: const Icon(Icons.stay_current_portrait),
            onPressed: () {
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
              ]);
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5FAFB),
      body: Column(
        children: [
          // FILTER CARD (SEARCH DI ATAS, FILTERS DIPISAH DI BAWAH)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Search bar (full width pill)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Cari nama, model, SN, atau no. inventaris',
                            prefixIcon: const Icon(Icons.search, color: Colors.teal),
                            suffixIcon: _search.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, color: Colors.grey),
                                    onPressed: () => setState(() {
                                      _search = '';
                                      _searchController.clear();
                                      _suggestions = [];
                                      _showSuggestions = false;
                                    }),
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (v) {
                            final q = v.trim();
                            setState(() {
                              _search = q.toLowerCase();
                            });

                            // Debounce and fetch suggestions
                            _debounce?.cancel();
                            _debounce = Timer(const Duration(milliseconds: 300), () async {
                              if (q.isEmpty) {
                                setState(() {
                                  _suggestions = [];
                                  _showSuggestions = false;
                                });
                                return;
                              }

                              try {
                                final snap = await FirebaseFirestore.instance
                                    .collection('items')
                                    .limit(100)
                                    .get();
                                final results = <Map<String, String>>[];
                                for (final doc in snap.docs) {
                                  final data = doc.data();
                                  final nama = (data['nama'] ?? '').toString();
                                  final sn = (data['sn'] ?? '').toString();
                                  final noInv = (data['no_inventaris'] ?? '').toString();
                                  final combined = '$nama $sn $noInv'.toLowerCase();
                                  if (combined.contains(q.toLowerCase())) {
                                    results.add({
                                      'id': doc.id,
                                      'nama': nama,
                                      'sn': sn,
                                      'no_inventaris': noInv,
                                    });
                                  }
                                }
                                setState(() {
                                  _suggestions = results;
                                  _showSuggestions = results.isNotEmpty;
                                });
                              } catch (e) {
                                setState(() {
                                  _suggestions = [];
                                  _showSuggestions = false;
                                });
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Row bawah: dua filter (kiri) dan spacer kanan
                Row(
                  children: [
                    // Filter Jenis (compact)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedJenis,
                          items: _jenisList.map((jenis) {
                            return DropdownMenuItem(
                              value: jenis,
                              child: Row(
                                children: [
                                  Icon(
                                    jenis == 'Printer' ? Icons.print :
                                    jenis == 'PC' ? Icons.computer :
                                    jenis == 'Switch' ? Icons.settings_ethernet :
                                    jenis == 'CCTV' ? Icons.videocam :
                                    jenis == 'Monitor' ? Icons.monitor :
                                    Icons.category,
                                    color: Colors.teal,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(jenis, style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() {
                            _selectedJenis = val!;
                            _currentPage = 0; // reset pagination
                          }),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Filter Status (compact)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          items: _statusList.map((status) {
                            IconData icon;
                            Color color;
                            switch (status) {
                              case 'Masuk': icon = Icons.move_to_inbox; color = Colors.green; break;
                              case 'Keluar': icon = Icons.outbox; color = Colors.orange; break;
                              case 'Rusak': icon = Icons.warning; color = Colors.red; break;
                              default: icon = Icons.all_inclusive; color = Colors.teal;
                            }
                            return DropdownMenuItem(
                              value: status,
                              child: Row(
                                children: [
                                  Icon(icon, color: color, size: 18),
                                  const SizedBox(width: 8),
                                  Text(status, style: TextStyle(color: Colors.black87, fontSize: 13)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() {
                            _selectedStatus = val!;
                            _currentPage = 0; // reset pagination
                          }),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                        ),
                      ),
                    ),

                    const Spacer(), // dorong filter ke kiri, sisakan ruang kanan
                  ],
                ),

                // SUGGESTIONS (tetap muncul di bawah search jika ada)
                if (_showSuggestions && _suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final s = _suggestions[index];
                        return ListTile(
                          dense: true,
                          title: Text(s['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('SN: ${s['sn'] ?? '-'} • Inv: ${s['no_inventaris'] ?? '-'}'),
                          onTap: () {
                            final text = '${s['nama'] ?? ''}';
                            setState(() {
                              _searchController.text = text;
                              _searchController.selection = TextSelection.collapsed(offset: text.length);
                              _search = text.toLowerCase();
                              _showSuggestions = false;
                              _suggestions = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          // DATA CARD LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('items')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Gagal memuat data'));
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>? ?? {};
                  final nama = (data['nama'] ?? '').toString().toLowerCase();
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  final jenis = (data['jenis'] ?? '').toString().toLowerCase();
                  final sn = (data['sn'] ?? '').toString().toLowerCase();
                  final noInventaris = (data['no_inventaris'] ?? '').toString().toLowerCase();
                  final idAset = d.id.toLowerCase();

                  final searchMatch = _search.isEmpty
                      || nama.contains(_search)
                      || sn.contains(_search)
                      || noInventaris.contains(_search)
                      || idAset.contains(_search);

                  final statusMatch = _selectedStatus == 'Semua'
                      || (_selectedStatus.toLowerCase() == 'tidak aktif' && status == 'rusak')
                      || status == _selectedStatus.toLowerCase();
                  final jenisMatch = _selectedJenis == 'Semua'
                      || jenis == _selectedJenis.toLowerCase();

                  return searchMatch && statusMatch && jenisMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Barang tidak ditemukan', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                // Pagination logic
                final totalPages = (filtered.length / _rowsPerPage).ceil();
                final startIndex = _currentPage * _rowsPerPage;
                final endIndex = ((startIndex + _rowsPerPage) > filtered.length)
                    ? filtered.length
                    : (startIndex + _rowsPerPage);
                final pageItems = filtered.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: pageItems.length,
                        itemBuilder: (context, idx) {
                          final doc = pageItems[idx];
                          final data = doc.data() as Map<String, dynamic>? ?? {};

                          String tanggalMasuk = '-';
                          String tanggalKeluar = '-';
                          String tanggalRusak = '-';

                          if (data['tanggal_masuk'] != null && data['tanggal_masuk'] is Timestamp) {
                            final dt = (data['tanggal_masuk'] as Timestamp).toDate();
                            tanggalMasuk = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
                          }
                          if (data['tanggal_keluar'] != null && data['tanggal_keluar'] is Timestamp) {
                            final dt = (data['tanggal_keluar'] as Timestamp).toDate();
                            tanggalKeluar = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
                          }
                          // tanggal rusak (jika ada)
                          if (data['tanggal_rusak'] != null && data['tanggal_rusak'] is Timestamp) {
                            final dt = (data['tanggal_rusak'] as Timestamp).toDate();
                            tanggalRusak = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
                          }

                          // Jika ada tanggal rusak, kosongkan tanggal keluar sesuai permintaan
                          if (tanggalRusak != '-') {
                            tanggalKeluar = '-';
                          }

                          final jamInput = data['jam_input'] ?? '-';
                          final status = (data['status'] ?? '-').toString().toLowerCase();
                          final keterangan = data['keterangan'] ?? '-';

                          Color statusColor;
                          switch (status) {
                            case 'masuk': statusColor = Colors.green.shade600; break;
                            case 'keluar': statusColor = Colors.orange.shade700; break;
                            case 'rusak': statusColor = Colors.red.shade700; break;
                            default: statusColor = Colors.grey.shade600;
                          }

                          // Untuk expand/collapse detail
                          return _ExpandableCard(
                            title: data['nama'] ?? '-',
                            status: status,
                            statusColor: statusColor,
                            popupMenu: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  Navigator.pushNamed(
                                    context,
                                    '/edit-barang',
                                    arguments: {
                                      'id': doc.id,
                                      ...data,
                                    },
                                  );
                                } else if (value == 'hapus') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Konfirmasi'),
                                      content: const Text('Yakin ingin menghapus data ini?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Batal'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await FirebaseFirestore.instance
                                        .collection('items')
                                        .doc(doc.id)
                                        .delete();
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit, color: Colors.blue),
                                    title: Text('Edit'),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'hapus',
                                  child: ListTile(
                                    leading: Icon(Icons.delete, color: Colors.red),
                                    title: Text('Hapus'),
                                  ),
                                ),
                              ],
                            ),
                            detail: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 24,
                                  runSpacing: 8,
                                  children: [
                                    _InfoItem(label: 'Model Barang', value: data['jenis'] ?? '-'),
                                    _InfoItem(label: 'Tanggal Masuk', value: tanggalMasuk),
                                    // tampilkan tanggal rusak jika ada, otherwise tampilkan tanggal keluar
                                    if (tanggalRusak != '-')
                                      _InfoItem(label: 'Tanggal Rusak', value: tanggalRusak)
                                    else
                                      _InfoItem(label: 'Tanggal Keluar', value: tanggalKeluar),
                                    _InfoItem(label: 'No. Inventaris', value: data['no_inventaris'] ?? '-'),
                                    _InfoItem(label: 'Serial Number (SN)', value: data['sn'] ?? '-'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Keterangan: ${data['keterangan'] ?? '-'}',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Pagination controls
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                          ),
                          Text(
                            'Halaman ${_currentPage + 1} dari $totalPages',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: (_currentPage < totalPages - 1)
                                ? () => setState(() => _currentPage++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Tambahkan widget info item di bawah kelas utama
class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: Colors.black87)),
      ],
    );
  }
}

class _ExpandableCard extends StatefulWidget {
  final String title;
  final String status;
  final Color statusColor;
  final Widget popupMenu;
  final Widget detail;

  const _ExpandableCard({
    required this.title,
    required this.status,
    required this.statusColor,
    required this.popupMenu,
    required this.detail,
    Key? key,
  }) : super(key: key);

  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<_ExpandableCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Garis hijau di atas card
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.status[0].toUpperCase() + widget.status.substring(1),
                    style: TextStyle(
                      color: widget.statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                widget.popupMenu,
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: Container(),
            secondChild: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: widget.detail,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(_expanded ? 'Show Less' : 'Show More'),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
        ],
      ),
    );
  }
}