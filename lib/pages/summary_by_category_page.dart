import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SummaryByCategoryPage extends StatefulWidget {
  const SummaryByCategoryPage({super.key});

  @override
  State<SummaryByCategoryPage> createState() => _SummaryByCategoryPageState();
}

class _SummaryByCategoryPageState extends State<SummaryByCategoryPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Future<Map<String, Map<String, int>>> _futureSummary = Future.value({});
  final List<Color> _palette = [
    const Color(0xFF6C5CE7),
    const Color(0xFF00B894),
    const Color(0xFFFF7675),
    const Color(0xFF00A8FF),
    const Color(0xFFFFB86B),
    const Color(0xFF8E44AD),
  ];

  // track expanded state per kategori name
  final Map<String, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    _futureSummary = _loadSummary();
  }

  Future<Map<String, Map<String, int>>> _loadSummary() async {
    final catSnap = await _db.collection('kategori').get().catchError((_) => throw 'Gagal ambil kategori');
    final barangSnap = await _db.collection('items').get().catchError((_) => throw 'Gagal ambil items');

    final Map<String, String> idToName = {};
    for (var doc in catSnap.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final name = (d['nama'] ?? d['name'] ?? '').toString();
      idToName[doc.id] = name.isNotEmpty ? name : doc.id;
    }

    final Map<String, Map<String, int>> result = {
      for (final name in idToName.values) 
      name: {
        'total': 0,
        'normal': 0,
        'rusak': 0
      }
    };

    for (var doc in barangSnap.docs) {
      final d = doc.data() as Map<String, dynamic>;

      // ambil kategori id / jenis untuk menentukan nama kategori
      final kategoriId = (d['kategori_id'] ?? d['kategoriId'] ?? '').toString();
      final jenisField = (d['jenis'] ?? d['kategori'] ?? '').toString();

      String kategoriName;
      if (kategoriId.isNotEmpty && idToName.containsKey(kategoriId)) {
        kategoriName = idToName[kategoriId]!;
      } else if (jenisField.isNotEmpty) {
        kategoriName = jenisField;
      } else {
        kategoriName = 'Uncategorized';
      }

      final entry = result.putIfAbsent(kategoriName, () => {
        'total': 0,
        'normal': 0,
        'rusak': 0
      });

      // hitung per dokumen (anda bisa sesuaikan jika pakai field 'jumlah')
      entry['total'] = entry['total']! + 1;

      // deteksi rusak: perhatikan field 'status' atau 'kondisi' di DB
      final status = (d['status'] ?? '').toString().toLowerCase();
      final kondisi = (d['kondisi'] ?? '').toString().toLowerCase();
      if (status == 'rusak' || kondisi == 'rusak') {
        entry['rusak'] = entry['rusak']! + 1;
      } else {
        entry['normal'] = entry['normal']! + 1;
      }
    }

    return result;
  }

  Future<void> _refresh() async {
    setState(() => _futureSummary = _loadSummary());
    await _futureSummary;
  }

  void _toggleExpand(String name) {
    setState(() {
      _expanded[name] = !(_expanded[name] ?? false);
    });
  }

  void _showCategoryBottomSheet(String name, Map<String, int> vals) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) {
        final total = vals['total'] ?? 0;
        // gunakan kunci konsisten
        final normal = vals['normal'] ?? 0;
        final broken = vals['rusak'] ?? 0;
        final ratio = total == 0 ? 0.0 : normal / total;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 48, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Total: $total', style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: ratio, minHeight: 10, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade400))),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _DetailStat(label: 'Normal', value: normal.toString(), color: Colors.green.shade600),
              _DetailStat(label: 'Rusak', value: broken.toString(), color: Colors.red.shade600),
            ]),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tutup'),
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
            const SizedBox(height: 6),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Colors.teal.shade700;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFB),
      appBar: AppBar(
        backgroundColor: mainColor,
        elevation: 0,
        title: const Text('Ringkasan Kategori', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: mainColor,
        child: FutureBuilder<Map<String, Map<String, int>>>(
          future: _futureSummary,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }

            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text('Gagal memuat: ${'' /* snap.error */}', style: const TextStyle(color: Colors.red)),
                  ),
                ],
              );
            }

            final summary = snap.data ?? {};
            final entries = summary.entries.toList()..sort((a, b) => b.value['total']!.compareTo(a.value['total']!));

            if (entries.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Tidak ada data barang atau kategori.', style: TextStyle(color: Colors.black54))),
                ],
              );
            }

            final totalItems = entries.fold<int>(0, (p, e) => p + (e.value['total'] ?? 0));
            final totalBroken = entries.fold<int>(0, (p, e) => p + (e.value['rusak'] ?? 0));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 6),

                // Cards list: tap to expand, swipe (drag) to open bottom sheet
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final e = entries[idx];
                    final name = e.key;
                    final vals = e.value;
                    final total = vals['total'] ?? 0;
                    final normal = vals['normal'] ?? 0;
                    final broken = vals['rusak'] ?? 0;
                    final color = _palette[idx % _palette.length];
                    final gradient = LinearGradient(
                      colors: [color.withOpacity(0.95), color.withOpacity(0.78)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    );
                    final isExpanded = _expanded[name] ?? false;

                    return GestureDetector(
                      onTap: () {
                        _toggleExpand(name);
                      },
                      onHorizontalDragEnd: (details) {
                        // small velocity threshold to consider as swipe
                        if (details.velocity.pixelsPerSecond.dx.abs() > 200) {
                          _showCategoryBottomSheet(name, vals);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.all(0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 8))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Column(
                            children: [
                              Container(
                                height: 110,
                                decoration: BoxDecoration(gradient: gradient),
                                child: Stack(
                                  children: [
                                    Positioned(right: -40, top: -40, child: Container(width: 120, height: 120, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
                                            child: Icon(Icons.devices, color: Colors.white, size: 34),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                                                const SizedBox(height: 8),
                                                Row(children: [
                                                  _MiniStat(label: 'Total', value: total.toString(), color: Colors.white70),
                                                  const SizedBox(width: 10),
                                                  _MiniStat(label: 'N', value: normal.toString(), color: Colors.white70),
                                                  const SizedBox(width: 10),
                                                  _MiniStat(label: 'R', value: broken.toString(), color: Colors.white70),
                                                ]),
                                              ],
                                            ),
                                          ),
                                          AnimatedRotation(
                                            turns: isExpanded ? 0.5 : 0,
                                            duration: const Duration(milliseconds: 300),
                                            child: Icon(Icons.expand_more, color: Colors.white.withOpacity(0.95), size: 30),
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // expanded area
                              AnimatedCrossFade(
                                firstChild: const SizedBox.shrink(),
                                secondChild: Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Column(
                                    children: [
                                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                        Text('Detail $name', style: const TextStyle(fontWeight: FontWeight.w700)),
                                        Text('Total: $total', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ]),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: total == 0 ? 0 : normal / total,
                                          minHeight: 10,
                                          backgroundColor: Colors.grey[200],
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade400),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                                        _DetailStat(label: 'Normal', value: normal.toString(), color: Colors.green.shade600),
                                        _VerticalDivider(),
                                        _DetailStat(label: 'Rusak', value: broken.toString(), color: Colors.red.shade600),
                                      ]),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => _showCategoryBottomSheet(name, vals),
                                            icon: const Icon(Icons.open_in_new, size: 18),
                                            label: const Text('Lihat lebih'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                duration: const Duration(milliseconds: 260),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                // bottom summary badges (moved to bottom as requested)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Ringkasan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text('Total kategori: ${entries.length}', style: TextStyle(color: Colors.grey.shade700)),
                        ]),
                        Row(children: [
                          _SmallBadge(label: 'Total', value: totalItems.toString(), color: mainColor),
                          const SizedBox(width: 10),
                          _SmallBadge(label: 'Rusak', value: totalBroken.toString(), color: Colors.red.shade600),
                        ])
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('$label: ', style: TextStyle(color: color, fontSize: 12)),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    ]);
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SmallBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.95), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ])
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DetailStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: TextStyle(color: Colors.black54, fontSize: 13)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
    ]);
  }
}

class _TinyChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TinyChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 12));
  }
}