import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Türkçe tarih için
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 1. Türkçe dil desteğini başlatıyoruz
  await initializeDateFormatting('tr_TR', null);
  runApp(
    const MaterialApp(
      home: YevmiyeTakipApp(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

class IsKaydi {
  final DateTime tarih;
  final TimeOfDay giris;
  final TimeOfDay cikis;
  final double saatlikUcret;
  final double gemiPrimi;

  IsKaydi({
    required this.tarih,
    required this.giris,
    required this.cikis,
    required this.saatlikUcret,
    required this.gemiPrimi,
  });

  // Saat farkını hesaplayan formül
  double get calismaSaati {
    final double girisDakika = giris.hour * 60.0 + giris.minute;
    final double cikisDakika = cikis.hour * 60.0 + cikis.minute;
    double fark = (cikisDakika - girisDakika) / 60.0;
    return fark > 0 ? fark : 0;
  }

  // HESAPLAMA BURADA: (Saat * Ücret) + Prim
  double get toplamKazanc => (calismaSaati * saatlikUcret) + gemiPrimi;

  Map<String, dynamic> toJson() => {
    'tarih': tarih.toIso8601String(),
    'gH': giris.hour,
    'gM': giris.minute,
    'cH': cikis.hour,
    'cM': cikis.minute,
    'u': saatlikUcret,
    'p': gemiPrimi,
  };

  factory IsKaydi.fromJson(Map<String, dynamic> json) => IsKaydi(
    tarih: DateTime.parse(json['tarih']),
    giris: TimeOfDay(hour: json['gH'], minute: json['gM']),
    cikis: TimeOfDay(hour: json['cH'], minute: json['cM']),
    saatlikUcret: json['u'],
    gemiPrimi: json['p'],
  );
}

class YevmiyeTakipApp extends StatefulWidget {
  const YevmiyeTakipApp({super.key});
  @override
  State<YevmiyeTakipApp> createState() => _YevmiyeTakipAppState();
}

class _YevmiyeTakipAppState extends State<YevmiyeTakipApp> {
  List<IsKaydi> _kayitlar = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  Future<void> _verileriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('yevmiye_v2');
    if (data != null) {
      final List decoded = json.decode(data);
      setState(() {
        _kayitlar = decoded.map((item) => IsKaydi.fromJson(item)).toList();
        _kayitlar.sort((a, b) => b.tarih.compareTo(a.tarih));
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _verileriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'yevmiye_v2',
      json.encode(_kayitlar.map((e) => e.toJson()).toList()),
    );
  }

  // Bu haftanın toplamını hesaplar
  double get _haftalikToplam {
    DateTime simdi = DateTime.now();
    DateTime pzt = simdi.subtract(Duration(days: simdi.weekday - 1));
    DateTime baslangic = DateTime(pzt.year, pzt.month, pzt.day);
    return _kayitlar
        .where(
          (k) =>
              k.tarih.isAfter(baslangic.subtract(const Duration(seconds: 1))),
        )
        .fold(0, (sum, item) => sum + item.toplamKazanc);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Yevmiye Takip"),
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Grafik Alanı
          Container(
            height: 230,
            decoration: const BoxDecoration(
              color: Color(0xFF2C3E50),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(sections: _getSections(), centerSpaceRadius: 60),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "HAFTALIK TOPLAM",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      "₺${_haftalikToplam.toStringAsFixed(0)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Liste Alanı
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 10),
              itemCount: _kayitlar.length,
              itemBuilder: (context, index) {
                final k = _kayitlar[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    onLongPress: () => _silmeOnayi(index),
                    title: Text(
                      DateFormat('EEEE, d MMMM', 'tr_TR').format(k.tarih),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "${k.giris.format(context)} - ${k.cikis.format(context)} (${k.calismaSaati.toStringAsFixed(1)} Saat)",
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "₺${k.toplamKazanc.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (k.gemiPrimi > 0)
                          Text(
                            "+₺${k.gemiPrimi.toStringAsFixed(0)} prim",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2C3E50),
        onPressed: () => _yeniEkle(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _silmeOnayi(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Kaydı Sil?"),
        content: const Text("Bu yevmiye kaydı kalıcı olarak silinecektir."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            onPressed: () {
              setState(() => _kayitlar.removeAt(index));
              _verileriKaydet();
              Navigator.pop(ctx);
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _yeniEkle(BuildContext context) {
    DateTime secilenTarih = DateTime.now();
    TimeOfDay g = const TimeOfDay(hour: 12, minute: 00);
    TimeOfDay c = const TimeOfDay(hour: 20, minute: 00);
    final ucretC = TextEditingController(text: "170");
    final primC = TextEditingController(text: "0");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "İş Girişi",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ListTile(
                title: Text(
                  "Tarih: ${DateFormat('d MMMM yyyy', 'tr_TR').format(secilenTarih)}",
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: secilenTarih,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setM(() => secilenTarih = d);
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: Text("Giriş: ${g.format(context)}"),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: g,
                        );
                        if (t != null) setM(() => g = t);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: Text("Çıkış: ${c.format(context)}"),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: c,
                        );
                        if (t != null) setM(() => c = t);
                      },
                    ),
                  ),
                ],
              ),
              TextField(
                controller: ucretC,
                decoration: const InputDecoration(
                  labelText: 'Saatlik Ücret (₺)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: primC,
                decoration: const InputDecoration(
                  labelText: 'Gemi Bitirme Primi (₺)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3E50),
                  ),
                  onPressed: () {
                    setState(() {
                      _kayitlar.add(
                        IsKaydi(
                          tarih: secilenTarih,
                          giris: g,
                          cikis: c,
                          saatlikUcret: double.tryParse(ucretC.text) ?? 0,
                          gemiPrimi: double.tryParse(primC.text) ?? 0,
                        ),
                      );
                      _kayitlar.sort((a, b) => b.tarih.compareTo(a.tarih));
                    });
                    _verileriKaydet();
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    "KAYDET",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _getSections() {
    final haftalik = _kayitlar.where((k) {
      DateTime pzt = DateTime.now().subtract(
        Duration(days: DateTime.now().weekday - 1),
      );
      return k.tarih.isAfter(
        DateTime(
          pzt.year,
          pzt.month,
          pzt.day,
        ).subtract(const Duration(seconds: 1)),
      );
    }).toList();

    if (haftalik.isEmpty)
      return [PieChartSectionData(value: 1, title: '', color: Colors.white12)];

    Map<int, double> gunler = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (var k in haftalik) {
      gunler[k.tarih.weekday] = (gunler[k.tarih.weekday] ?? 0) + k.toplamKazanc;
    }

    List<Color> renkler = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.cyan,
      Colors.yellow,
    ];
    return gunler.entries
        .where((e) => e.value > 0)
        .map(
          (e) => PieChartSectionData(
            color: renkler[e.key - 1],
            value: e.value,
            radius: 50,
            title:
                '${DateFormat('E', 'tr_TR').format(DateTime(2024, 1, e.key + 1))}\n₺${e.value.toStringAsFixed(0)}',
            titleStyle: const TextStyle(
              fontSize: 9,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        )
        .toList();
  }
}
