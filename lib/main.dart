import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'db_helper.dart';
import 'generator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MaterialApp(home: MainApp(), debugShowCheckedModeBanner: false));
}

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);
  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  List<Eleveur> _eleveurs = [];
  final TextEditingController _dateVController = TextEditingController();
  final TextEditingController _dateCController = TextEditingController();

  List<File> _templates = [];
  File? _selectedTemplate;

  List<String> _customVariableNames = [];

  final List<String> _baseVariables = [
    '{{nom}}',
    '{{pere}}',
    '{{cin}}',
    '{{date_cin}}',
    '{{daira}}',
    '{{ovins}}',
    '{{brebis}}',
    '{{date_v}}',
    '{{date_c}}',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadTemplates();
  }

  void _loadData() async {
    final data = await DatabaseHelper.getEleveurs();
    Set<String> savedKeys = {};
    for (var e in data) {
      savedKeys.addAll(e.customData.keys); // يجبد المتغيرات اللي تسجلت من قبل
    }

    setState(() {
      _eleveurs = data;
      for (var k in savedKeys) {
        if (!_customVariableNames.contains(k)) _customVariableNames.add(k);
      }
    });
  }

  Future<void> _loadTemplates() async {
    final dir = await getApplicationDocumentsDirectory();
    final tDir = Directory(p.join(dir.path, 'vet_templates'));
    if (!await tDir.exists()) await tDir.create();

    final files = tDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.docx'))
        .toList();
    setState(() {
      _templates = files;
      if (_templates.isNotEmpty && !_templates.contains(_selectedTemplate)) {
        _selectedTemplate = _templates.first;
      }
    });
  }

  Future<void> _importTemplate() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (result != null && result.files.single.path != null) {
      File source = File(result.files.single.path!);
      final dir = await getApplicationDocumentsDirectory();
      final tDir = Directory(p.join(dir.path, 'vet_templates'));
      if (!await tDir.exists()) await tDir.create();

      String newPath = p.join(tDir.path, p.basename(source.path));
      await source.copy(newPath);
      await _loadTemplates();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم حفظ المودال!", textDirection: TextDirection.rtl),
        ),
      );
    }
  }

  void _deleteEleveur(int id) async {
    await DatabaseHelper.deleteEleveur(id);
    _loadData();
  }

  // النافذة الجديدة لإدارة وحذف وإضافة المتغيرات المخصصة
  void _manageCustomVariablesDialog() {
    TextEditingController varName = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // هذي تخلي النافذة تتحدث كي نمحيو متغير
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                "إدارة المتغيرات المخصصة",
                textDirection: TextDirection.rtl,
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_customVariableNames.isEmpty)
                      const Text(
                        "لا توجد متغيرات حالياً.",
                        textDirection: TextDirection.rtl,
                        style: TextStyle(color: Colors.grey),
                      ),

                    // قائمة المتغيرات الحالية مع زر الحذف
                    ..._customVariableNames
                        .map(
                          (v) => ListTile(
                            title: Text(
                              v,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setDialogState(
                                  () => _customVariableNames.remove(v),
                                );
                                setState(() {
                                  for (var e in _eleveurs) {
                                    if (e.customData.containsKey(v)) {
                                      e.customData.remove(v);
                                      DatabaseHelper.updateEleveur(
                                        e,
                                      ); // تحديث قاعدة البيانات
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                        )
                        .toList(),
                    const Divider(),

                    // خانة إضافة متغير جديد
                    TextField(
                      controller: varName,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        hintText: "اسم متغير جديد (مثال: age)",
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إغلاق"),
                ),
                TextButton(
                  onPressed: () {
                    if (varName.text.isNotEmpty &&
                        !_customVariableNames.contains(varName.text)) {
                      setDialogState(() {
                        _customVariableNames.add(varName.text);
                        varName.clear();
                      });
                      setState(() {});
                    }
                  },
                  child: const Text(
                    "إضافة",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _eleveurDialog({Eleveur? eleveur}) {
    bool isEditing = eleveur != null;
    TextEditingController nom = TextEditingController(text: eleveur?.nom ?? "");
    TextEditingController pere = TextEditingController(
      text: eleveur?.pere ?? "",
    );
    TextEditingController cin = TextEditingController(text: eleveur?.cin ?? "");
    TextEditingController dateCin = TextEditingController(
      text: eleveur?.dateCin ?? "",
    );
    TextEditingController daira = TextEditingController(
      text: eleveur?.daira ?? "",
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isEditing ? "تعديل مربي" : "إضافة مربي",
            textDirection: TextDirection.rtl,
          ),
          content: SingleChildScrollView(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nom,
                    decoration: const InputDecoration(
                      labelText: "الاسم واللقب",
                    ),
                  ),
                  TextField(
                    controller: pere,
                    decoration: const InputDecoration(labelText: "اسم الأب"),
                  ),
                  TextField(
                    controller: cin,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "رقم البطاقة"),
                  ),
                  TextField(
                    controller: dateCin,
                    decoration: const InputDecoration(
                      labelText: "تاريخ الإصدار",
                    ),
                  ),
                  TextField(
                    controller: daira,
                    decoration: const InputDecoration(labelText: "الدائرة"),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء"),
            ),
            TextButton(
              onPressed: () async {
                Eleveur newEleveur = Eleveur(
                  id: eleveur?.id,
                  nom: nom.text,
                  pere: pere.text,
                  cin: cin.text,
                  dateCin: dateCin.text,
                  daira: daira.text,
                  customData: eleveur?.customData ?? {},
                );
                if (isEditing)
                  await DatabaseHelper.updateEleveur(newEleveur);
                else
                  await DatabaseHelper.insertEleveur(newEleveur);
                _loadData();
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: Text(isEditing ? "تحديث" : "حفظ"),
            ),
          ],
        );
      },
    );
  }

  void _generate() async {
    if (_selectedTemplate == null) return;
    String? selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: "اختر مسار الحفظ",
    );
    if (selectedDirectory != null) {
      // نبعثو _customVariableNames للـ Generator باش يقدر يعوض الفارغين
      await DocxGenerator.generateCertificates(
        _eleveurs,
        _dateVController.text,
        _dateCController.text,
        _selectedTemplate!.path,
        selectedDirectory,
        _customVariableNames,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "تم استخراج الشهادات بنجاح!",
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> allVariables = List.from(_baseVariables);
    allVariables.addAll(_customVariableNames.map((v) => '{{$v}}'));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "إصدار الشهادات",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              height: 50,
              color: Colors.grey.shade100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: allVariables
                    .map(
                      (v) => Padding(
                        padding: const EdgeInsets.only(
                          left: 8.0,
                          top: 6,
                          bottom: 6,
                        ),
                        child: ActionChip(
                          label: Text(
                            v,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: Colors.blue.shade50,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: v));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "تم نسخ: $v",
                                  textDirection: TextDirection.rtl,
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            ExpansionTile(
              title: const Text(
                "⚙️ إعدادات التواريخ والقوالب (إضغط للفتح/الإغلاق)",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              initiallyExpanded: false,
              childrenPadding: const EdgeInsets.all(12),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _templates.isEmpty
                          ? const Text(
                              "أضف مودال Word",
                              style: TextStyle(color: Colors.red),
                            )
                          : DropdownButton<File>(
                              isExpanded: true,
                              value: _selectedTemplate,
                              items: _templates
                                  .map(
                                    (f) => DropdownMenuItem(
                                      value: f,
                                      child: Text(p.basename(f.path)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (File? val) =>
                                  setState(() => _selectedTemplate = val),
                            ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.upload_file, color: Colors.blue),
                      onPressed: _importTemplate,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dateVController,
                        decoration: const InputDecoration(
                          labelText: "تاريخ التلقيح",
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _dateCController,
                        decoration: const InputDecoration(
                          labelText: "تاريخ الشهادة",
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _manageCustomVariablesDialog, // زر إدارة المتغيرات
                  icon: const Icon(Icons.settings),
                  label: const Text("إدارة المتغيرات الإضافية (إضافة/حذف)"),
                ),
              ],
            ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => setState(() {
                      for (var e in _eleveurs) e.isSelected = true;
                    }),
                    icon: const Icon(Icons.check_box),
                    label: const Text("الكل"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {
                      for (var e in _eleveurs) e.isSelected = false;
                    }),
                    icon: const Icon(Icons.check_box_outline_blank),
                    label: const Text("إلغاء"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _eleveurDialog(),
                    icon: const Icon(Icons.person_add),
                    label: const Text("مربي جديد"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _generate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text("إصدار"),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _eleveurs.length,
                itemBuilder: (context, index) {
                  final e = _eleveurs[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${e.nom} - (${e.daira})",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: () => _eleveurDialog(eleveur: e),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _deleteEleveur(e.id!),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      subtitle: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (val) => e.ovins = val,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "الأغنام (Ovins)",
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  onChanged: (val) => e.brebis = val,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "النعاج (Brebis)",
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_customVariableNames.isNotEmpty)
                            Wrap(
                              spacing: 10,
                              children: _customVariableNames.map((varName) {
                                return SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.4,
                                  child: TextField(
                                    controller: TextEditingController(
                                      text: e.customData[varName] ?? "",
                                    ), // باش كي تحذف وترجع يلقى القديم
                                    onChanged: (val) {
                                      e.customData[varName] = val;
                                      DatabaseHelper.updateEleveur(
                                        e,
                                      ); // يحفظ التغيير أوتوماتيكيا
                                    },
                                    decoration: InputDecoration(
                                      labelText: varName,
                                      isDense: true,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                      value: e.isSelected,
                      onChanged: (bool? val) =>
                          setState(() => e.isSelected = val ?? false),
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
}
