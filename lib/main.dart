import 'package:comic_editor/project_hive_model.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'PanelLayoutEditorScreen.dart';
import 'ProjectsListScreen.dart';


/*void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);

  Hive.registerAdapter(ProjectHiveModelAdapter());
  Hive.registerAdapter(LayoutPanelHiveModelAdapter());

  await Hive.openBox<ProjectHiveModel>('drafts');

  runApp(MyApp());
}*/

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive with the correct method for your version
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);

  // Alternative: If you have hive_flutter package, use:
  // await Hive.initFlutter();

  // Register adapters with correct type IDs
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ProjectHiveModelAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(LayoutPanelHiveModelAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(PanelElementModelHiveModelAdapter());
  }

  // Open the box
  await Hive.openBox<ProjectHiveModel>('drafts');

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comic Panel Editor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ProjectsListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}


