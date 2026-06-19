import 'dart:io';
import 'package:docx_template/docx_template.dart';
import 'package:path/path.dart' as p;
import 'db_helper.dart';

class DocxGenerator {
  static Future<void> generateCertificates(
    List<Eleveur> eleveurs,
    String dateVaccin,
    String dateCertificat,
    String templatePath,
    String outputDirPath,
    List<String> customVariableNames,
  ) async {
    final file = File(templatePath);
    final bytes = await file.readAsBytes();

    for (var eleveur in eleveurs) {
      if (eleveur.isSelected) {
        final docx = await DocxTemplate.fromBytes(bytes);
        Content content = Content();

        // هنا المتغيرات خليها كيما راهي، المكتبة تزيدلها {#} أوتوماتيكيا في الوورد
        content
          ..add(TextContent("nom", eleveur.nom.isNotEmpty ? eleveur.nom : ""))
          ..add(
            TextContent("pere", eleveur.pere.isNotEmpty ? eleveur.pere : ""),
          )
          ..add(TextContent("cin", eleveur.cin.isNotEmpty ? eleveur.cin : ""))
          ..add(
            TextContent(
              "date_cin",
              eleveur.dateCin.isNotEmpty ? eleveur.dateCin : "",
            ),
          )
          ..add(
            TextContent("daira", eleveur.daira.isNotEmpty ? eleveur.daira : ""),
          )
          ..add(
            TextContent("ovins", eleveur.ovins.isNotEmpty ? eleveur.ovins : ""),
          )
          ..add(
            TextContent(
              "brebis",
              eleveur.brebis.isNotEmpty ? eleveur.brebis : "",
            ),
          )
          ..add(TextContent("date_v", dateVaccin.isNotEmpty ? dateVaccin : ""))
          ..add(
            TextContent(
              "date_c",
              dateCertificat.isNotEmpty ? dateCertificat : "",
            ),
          );

        for (var varName in customVariableNames) {
          String val = eleveur.customData[varName] ?? "";
          content.add(TextContent(varName, val));
        }

        final d = await docx.generate(content);

        if (d != null) {
          String safeName = eleveur.nom.isEmpty
              ? "Inconnu"
              : eleveur.nom.replaceAll(" ", "_").replaceAll("/", "");
          final outFile = File(
            p.join(outputDirPath, 'Certificat_$safeName.docx'),
          );
          await outFile.writeAsBytes(d);
        } else {
          // هادي باش إذا كان الوورد غالط ما يسكتش، يخرجلك إيرور باش تفيق
          throw Exception(
            "الملف فارغ أو لا يحتوي على متغيرات صحيحة! تأكد من كتابة المتغيرات بهذا الشكل: {#nom}",
          );
        }
      }
    }
  }
}
