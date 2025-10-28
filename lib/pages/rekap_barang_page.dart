// ignore_for_file: unused_local_variable, unused_element, unnecessary_cast

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart'; // gunakan XFile yang benar
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RekapBarangPage extends StatefulWidget {
  const RekapBarangPage({super.key});

  @override
  State<RekapBarangPage> createState() => _RekapBarangPageState();
}

class _RekapBarangPageState extends State<RekapBarangPage> {
  bool _loading = false;

  Future<bool> _requestStoragePermission() async {
    var status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<Map<String, int>> getTotalBarang() async {
    final snapshot = await FirebaseFirestore.instance.collection('items').get();
    int masuk = 0, keluar = 0, rusak = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString().toLowerCase();
      final jumlah = int.tryParse(data['jumlah']?.toString() ?? '0') ?? 0;
      if (status == 'masuk') masuk += jumlah;
      if (status == 'keluar') keluar += jumlah;
      if (status == 'rusak') rusak += jumlah;
    }
    return {'masuk': masuk, 'keluar': keluar, 'rusak': rusak};
  }

  Future<String> _getDownloadPath() async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (await directory.exists()) return directory.path;
      } else {
        final d = await getDownloadsDirectory();
        if (d != null) return d.path;
      }
    } catch (_) {}
    final appDoc = await getApplicationDocumentsDirectory();
    return appDoc.path;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    try {
      if (value is Timestamp) {
        final dt = value.toDate();
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      } else if (value is DateTime) {
        final dt = value;
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      } else {
        final s = value.toString();
        if (s.isEmpty) return '-';
        return s;
      }
    } catch (_) {
      return value.toString();
    }
  }

  Future<void> _exportBarangToExcel(BuildContext context) async {
    final granted = await _requestStoragePermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin penyimpanan diperlukan untuk menyimpan file.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .orderBy('createdAt', descending: true)
          .get();

      final excel = Excel.createExcel();
      final Sheet sheet = excel['Sheet1'];

      sheet.appendRow([
        'Nama',
        'Model',
        'Tanggal Masuk',
        'Tanggal Keluar',
        'Tanggal Rusak', // <-- ditambahkan
        'No Inventaris',
        'SN',
        'Status',
        'Keterangan',
      ]);

      for (final doc in snapshot.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final tMasukRaw = d['tanggal_masuk'] ?? d['tanggal'];
        final tKeluarRaw = d['tanggal_keluar'];
        final tRusakRaw = d['tanggal_rusak']; // <-- ambil tanggal rusak

        final tanggalMasuk = _formatDate(tMasukRaw);
        final tanggalKeluar = _formatDate(tKeluarRaw);
        final tanggalRusak = _formatDate(tRusakRaw); // <-- format tanggal rusak

        sheet.appendRow([
          d['nama'] ?? '',
          d['jenis'] ?? '',
          tanggalMasuk,
          tanggalKeluar,
          tanggalRusak, // <-- masukkan ke baris
          d['no_inventaris'] ?? '',
          d['sn'] ?? '',
          d['status'] ?? '',
          d['keterangan'] ?? '',
        ]);
      }

      final excelBytes = excel.encode();
      if (excelBytes == null) throw Exception('Gagal membuat file Excel.');

      String filePath;
      File file;
      final fileName = 'Rekap_Data_Barang_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          filePath = '${downloadDir.path}/$fileName';
          file = File(filePath);
          await file.writeAsBytes(excelBytes);
        } else {
          throw Exception('Download dir tidak ada');
        }
      } catch (_) {
        final appDir = await getApplicationDocumentsDirectory();
        filePath = '${appDir.path}/$fileName';
        file = File(filePath);
        await file.writeAsBytes(excelBytes);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rekap data berhasil disimpan di:\n$filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Buka',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  await Share.shareXFiles([XFile(filePath)], text: 'Rekap Data Barang');
                } catch (_) {}
              },
            ),
          ),
        );

        _showExportResultDialog(context, filePath);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan rekap data barang!\nDetail error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _loading = false);
  }

  void _showExportResultDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.green.shade600,
                  child: const Icon(Icons.check, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(
                  'Berhasil diunduh',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'File rekap telah disimpan.',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                Text(
                  filePath,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Buka / Bagikan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    try {
                      await Share.shareXFiles([XFile(filePath)], text: 'Rekap Data Barang');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal membuka file: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Tutup', style: TextStyle(color: Colors.green.shade700)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Colors.teal.shade700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFB),
      appBar: AppBar(
        title: const Text('Rekap Data Barang'),
        backgroundColor: mainColor,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, int>>(
        future: getTotalBarang(),
        builder: (context, snap) {
          final stat = snap.data ?? {'masuk': 0, 'keluar': 0, 'rusak': 0};
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header card (clean)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: mainColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.table_view, color: mainColor, size: 34),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rekap Data Barang',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: mainColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Export seluruh data barang ke file Excel. File akan disimpan di folder Download jika tersedia, otherwise di direktori aplikasi.',
                              style: TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ), // end header container

                const SizedBox(height: 18),

                // Ringkasan dihilangkan untuk tampilan lebih bersih
                // (sebelumnya ada Center(...) yang menampilkan total masuk/keluar/rusak)

                const SizedBox(height: 6),

                // Export button (lebih menonjol)
                _loading
                    ? Column(
                        children: [
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(mainColor)),
                          const SizedBox(height: 14),
                          const Text('Mengekspor data...'),
                        ],
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.file_download),
                        label: const Text('Export Rekap Data Barang ke Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _exportBarangToExcel(context),
                      ),

                const SizedBox(height: 12),

                // Tips kecil
                Text(
                  'Tip: Jika file tidak muncul di folder Download, cek notifikasi atau gunakan tombol "Buka" untuk membagikan/menyimpan secara manual.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Card statistik barang
class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 90,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }
}