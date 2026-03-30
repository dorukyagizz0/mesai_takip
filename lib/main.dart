import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Takvim ve dil desteği için bu paketleri eklemeyi unutma (pubspec.yaml içinde flutter_localizations olmalı)
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  runApp(
    const MaterialApp(
      home: AnaIskelet(),
      debugShowCheckedModeBanner: false,
      title: "Mesai Takip",
      // TAKVİMİN TÜRKÇE OLMASI İÇİN GEREKLİ AYARLAR
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('tr', 'TR')],
      locale: Locale('tr', 'TR'),
    ),
  );
}

class IsKaydi {
  String id;
  DateTime girisZamani;
  DateTime cikisZamani;
  double saatlikUcret;
  double gemiPrimi;

  IsKaydi({
    required this.id,
    required this.girisZamani,
    required this.cikisZamani,
    required this.saatlikUcret,
    required this.gemiPrimi,
  });

  double get calismaSaati =>
      cikisZamani.difference(girisZamani).inMinutes / 60.0;
  double get toplamKazanc => (calismaSaati * saatlikUcret) + gemiPrimi;

  Map<String, dynamic> toJson() => {
    'id': id,
    'gZ': girisZamani.toIso8601String(),
    'cZ': cikisZamani.toIso8601String(),
    'u': saatlikUcret,
    'p': gemiPrimi,
  };
  factory IsKaydi.fromJson(Map<String, dynamic> json) => IsKaydi(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    girisZamani: DateTime.parse(json['gZ']),
    cikisZamani: DateTime.parse(json['cZ']),
    saatlikUcret: json['u'].toDouble(),
    gemiPrimi: json['p'].toDouble(),
  );
}

class _AnaIskeletState extends State<AnaIskelet> {
  int _seciliSayfa = 0;
  List<IsKaydi> _kayitlar = [];

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  Future<void> _verileriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('mesai_v7');
    if (data != null) {
      final List decoded = json.decode(data);
      if (mounted) {
        setState(() {
          _kayitlar = decoded.map((item) => IsKaydi.fromJson(item)).toList();
          _kayitlar.sort((a, b) => b.girisZamani.compareTo(a.girisZamani));
        });
      }
    }
  }

  void _kayitKaydet(IsKaydi kayit) {
    setState(() {
      final index = _kayitlar.indexWhere((e) => e.id == kayit.id);
      if (index != -1) {
        _kayitlar[index] = kayit;
      } else {
        _kayitlar.add(kayit);
      }
      _kayitlar.sort((a, b) => b.girisZamani.compareTo(a.girisZamani));
    });
    _verileriKaydet();
  }

  void _kayitSil(String id) {
    setState(() => _kayitlar.removeWhere((e) => e.id == id));
    _verileriKaydet();
  }

  Future<void> _verileriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'mesai_v7',
      json.encode(_kayitlar.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: IndexedStack(
        index: _seciliSayfa,
        children: [
          AnaSayfa(
            kayitlar: _kayitlar,
            onKaydet: _kayitKaydet,
            onSil: _kayitSil,
          ),
          IstatistikSayfasi(kayitlar: _kayitlar),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _seciliSayfa,
        onTap: (i) => setState(() => _seciliSayfa = i),
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_rounded),
            label: "Mesailer",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: "Analiz",
          ),
        ],
      ),
    );
  }
}

class AnaIskelet extends StatefulWidget {
  const AnaIskelet({super.key});
  @override
  State<AnaIskelet> createState() => _AnaIskeletState();
}

class AnaSayfa extends StatelessWidget {
  final List<IsKaydi> kayitlar;
  final Function(IsKaydi) onKaydet;
  final Function(String) onSil;

  const AnaSayfa({
    super.key,
    required this.kayitlar,
    required this.onKaydet,
    required this.onSil,
  });

  @override
  Widget build(BuildContext context) {
    double toplamGenel = kayitlar.fold(
      0,
      (sum, item) => sum + item.toplamKazanc,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Mesai Takip", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 50,
                      sections: kayitlar.take(5).toList().asMap().entries.map((
                        e,
                      ) {
                        return PieChartSectionData(
                          color: Colors.blueAccent.withOpacity(
                            0.5 + (e.key * 0.1),
                          ),
                          value: e.value.toplamKazanc,
                          title: '',
                          radius: 12,
                        );
                      }).toList(),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "TOPLAM",
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      Text(
                        "₺${toplamGenel.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _card(context, kayitlar[i]),
                childCount: kayitlar.length,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _modal(context),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _card(BuildContext context, IsKaydi k) {
    return Dismissible(
      key: Key(k.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onSil(k.id),
      child: Card(
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          onTap: () => _modal(context, mevcut: k),
          title: Text(
            DateFormat('d MMMM EEEE', 'tr_TR').format(k.girisZamani),
            style: const TextStyle(color: Colors.white),
          ),
          // İSTEDİĞİN GÜNCELLEME: SAAT VE TOPLAM SÜRE
          subtitle: Text(
            "${DateFormat('HH:mm').format(k.girisZamani)} - ${DateFormat('HH:mm').format(k.cikisZamani)} (${k.calismaSaati.toStringAsFixed(1)} sa)",
            style: const TextStyle(color: Colors.white54),
          ),
          trailing: Text(
            "₺${k.toplamKazanc.toStringAsFixed(0)}",
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _modal(BuildContext context, {IsKaydi? mevcut}) {
    DateTime gT = mevcut?.girisZamani ?? DateTime.now();
    DateTime cT =
        mevcut?.cikisZamani ?? DateTime.now().add(const Duration(hours: 8));
    final uC = TextEditingController(
      text: mevcut?.saatlikUcret.toStringAsFixed(0) ?? "170",
    );
    final pC = TextEditingController(
      text: mevcut?.gemiPrimi.toStringAsFixed(0) ?? "180",
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20,
            left: 25,
            right: 25,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Mesai Bilgisi",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _dt(ctx, "Giriş", gT, (nd) => setM(() => gT = nd)),
              _dt(ctx, "Çıkış", cT, (nd) => setM(() => cT = nd)),
              TextField(
                controller: uC,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Saatlik Ücret"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pC,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Gemi Primi"),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: const Text("180₺"),
                    selected: pC.text == "180",
                    onSelected: (s) => setM(() => pC.text = "180"),
                  ),
                  ChoiceChip(
                    label: const Text("220₺"),
                    selected: pC.text == "220",
                    onSelected: (s) => setM(() => pC.text = "220"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  onKaydet(
                    IsKaydi(
                      id:
                          mevcut?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      girisZamani: gT,
                      cikisZamani: cT,
                      saatlikUcret: double.tryParse(uC.text) ?? 170,
                      gemiPrimi: double.tryParse(pC.text) ?? 0,
                    ),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text("KAYDET"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dt(
    BuildContext context,
    String l,
    DateTime d,
    Function(DateTime) os,
  ) {
    return ListTile(
      title: Text(
        l,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      subtitle: Text(
        DateFormat('d MMMM, HH:mm', 'tr_TR').format(d),
        style: const TextStyle(color: Colors.white),
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: d,
          firstDate: DateTime(2025),
          lastDate: DateTime(2030),
          locale: const Locale('tr', 'TR'), // TAKVİM BURADA DA TÜRKÇELEŞTİ
        );
        if (!context.mounted) return;
        if (date != null) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(d),
            builder: (context, child) => Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(primary: Colors.blueAccent),
              ),
              child: child!,
            ),
          );
          if (!context.mounted) return;
          if (time != null) {
            os(
              DateTime(date.year, date.month, date.day, time.hour, time.minute),
            );
          }
        }
      },
    );
  }
}

class IstatistikSayfasi extends StatefulWidget {
  final List<IsKaydi> kayitlar;
  const IstatistikSayfasi({super.key, required this.kayitlar});

  @override
  State<IstatistikSayfasi> createState() => _IstatistikSayfasiState();
}

class _IstatistikSayfasiState extends State<IstatistikSayfasi> {
  DateTimeRange? _seciliAralik;

  @override
  Widget build(BuildContext context) {
    List<IsKaydi> filtrelenmis = widget.kayitlar;
    if (_seciliAralik != null) {
      filtrelenmis = widget.kayitlar.where((k) {
        return k.girisZamani.isAfter(
              _seciliAralik!.start.subtract(const Duration(seconds: 1)),
            ) &&
            k.girisZamani.isBefore(
              _seciliAralik!.end.add(const Duration(days: 1)),
            );
      }).toList();
    } else {
      filtrelenmis = widget.kayitlar
          .where((k) => k.girisZamani.month == DateTime.now().month)
          .toList();
    }

    double toplamPara = filtrelenmis.fold(
      0,
      (sum, item) => sum + item.toplamKazanc,
    );
    double toplamSaat = filtrelenmis.fold(
      0,
      (sum, item) => sum + item.calismaSaati,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "Analiz ve Filtre",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        actions: [
          if (_seciliAralik != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.redAccent),
              onPressed: () => setState(() => _seciliAralik = null),
            ),
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.blueAccent),
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
                locale: const Locale('tr', 'TR'), // ANALİZ TAKVİMİ TÜRKÇE
                builder: (context, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Colors.blueAccent,
                      surface: Color(0xFF1E293B),
                    ),
                  ),
                  child: child!,
                ),
              );
              if (range != null) setState(() => _seciliAralik = range);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _seciliAralik == null
                        ? "BU AYIN TOPLAMI"
                        : "SEÇİLİ ARALIK TOPLAMI",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "₺${toplamPara.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ozetBilgi(
                        "Toplam Saat",
                        "${toplamSaat.toStringAsFixed(1)} sa",
                      ),
                      _ozetBilgi("Mesai Sayısı", "${filtrelenmis.length} gün"),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: filtrelenmis.length,
                itemBuilder: (context, i) {
                  final k = filtrelenmis[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      DateFormat('d MMMM', 'tr_TR').format(k.girisZamani),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: Text(
                      "₺${k.toplamKazanc.toStringAsFixed(0)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ozetBilgi(String baslik, String deger) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          baslik,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        Text(
          deger,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
