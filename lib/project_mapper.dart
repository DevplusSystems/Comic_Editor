import 'dart:typed_data';
import 'package:comic_editor/project_hive_model.dart';
import 'package:flutter/material.dart';
import 'Project.dart';
import 'PanelElementModel.dart';

// Convert Project to Hive model
ProjectHiveModel toHiveModel(Project project) {
  print('=== CONVERTING TO HIVE MODEL ===');
  print('Project: ${project.name}');
  print('Pages count: ${project.pages.length}');

  final hivePages = <List<LayoutPanelHiveModel>>[];

  for (int pageIndex = 0; pageIndex < project.pages.length; pageIndex++) {
    final page = project.pages[pageIndex];
    print('Converting page $pageIndex with ${page.length} panels');

    final hivePanels = <LayoutPanelHiveModel>[];

    for (int panelIndex = 0; panelIndex < page.length; panelIndex++) {
      final panel = page[panelIndex];
      print('Converting panel $panelIndex (${panel.id}) with ${panel.elements.length} elements');

      // Convert elements to Hive models with detailed logging
      final hiveElements = <PanelElementModelHiveModel>[];
      for (int elementIndex = 0; elementIndex < panel.elements.length; elementIndex++) {
        final element = panel.elements[elementIndex];
        print('  Converting element $elementIndex: ${element.type} - "${element.value}"');
        print('    Element details: id=${element.id}, offset=${element.offset}, size=${element.size}');

        final hiveElement = PanelElementModelHiveModel(
          id: element.id,
          type: element.type,
          value: element.value,
          width: element.width,
          height: element.height,
          offsetDx: element.offset.dx,
          offsetDy: element.offset.dy,
          sizeWidth: element.size?.width,
          sizeHeight: element.size?.height,
          colorValue: element.color?.value,
          fontSize: element.fontSize,
          fontFamily: element.fontFamily,
        );

        hiveElements.add(hiveElement);
        print('    Hive element created: ${hiveElement.type} - "${hiveElement.value}"');
      }

      final hivePanel = LayoutPanelHiveModel(
        id: panel.id,
        width: panel.width,
        height: panel.height,
        x: panel.x,
        y: panel.y,
        customText: panel.customText,
        backgroundColorValue: panel.backgroundColor.value,
        previewImage: panel.previewImage?.toList(),
        elements: hiveElements, // This should now contain the elements
      );

      hivePanels.add(hivePanel);
      print('  Hive panel created with ${hivePanel.elements.length} elements');
    }

    hivePages.add(hivePanels);
  }

  final hiveModel = ProjectHiveModel(
    id: project.id,
    name: project.name,
    createdAt: project.createdAt,
    lastModified: project.lastModified,
    thumbnail: project.thumbnail?.toList(),
    pages: hivePages,
  );

  print('Hive model created with ${hiveModel.pages.length} pages');
  return hiveModel;
}

// Convert Hive model to Project
Project fromHiveModel(ProjectHiveModel model) {
  print('=== CONVERTING FROM HIVE MODEL ===');
  print('Project: ${model.name}');
  print('Pages count: ${model.pages.length}');

  final projectPages = <List<LayoutPanel>>[];

  for (int pageIndex = 0; pageIndex < model.pages.length; pageIndex++) {
    final hivePage = model.pages[pageIndex];
    print('Converting hive page $pageIndex with ${hivePage.length} panels');

    final panels = <LayoutPanel>[];

    for (int panelIndex = 0; panelIndex < hivePage.length; panelIndex++) {
      final hivePanel = hivePage[panelIndex];
      print('Converting hive panel ${hivePanel.id} with ${hivePanel.elements.length} elements');

      // Convert elements from Hive models with detailed logging
      final elements = <PanelElementModel>[];
      for (int elementIndex = 0; elementIndex < hivePanel.elements.length; elementIndex++) {
        final hiveElement = hivePanel.elements[elementIndex];
        print('  Converting hive element $elementIndex: ${hiveElement.type} - "${hiveElement.value}"');
        print('    Hive element details: id=${hiveElement.id}, offsetDx=${hiveElement.offsetDx}, offsetDy=${hiveElement.offsetDy}');

        final element = PanelElementModel(
          id: hiveElement.id,
          type: hiveElement.type,
          value: hiveElement.value,
          width: hiveElement.width,
          height: hiveElement.height,
          offset: Offset(hiveElement.offsetDx, hiveElement.offsetDy),
          size: hiveElement.sizeWidth != null && hiveElement.sizeHeight != null
              ? Size(hiveElement.sizeWidth!, hiveElement.sizeHeight!)
              : null,
          color: hiveElement.colorValue != null ? Color(hiveElement.colorValue!) : null,
          fontSize: hiveElement.fontSize,
          fontFamily: hiveElement.fontFamily,
        );

        elements.add(element);
        print('    Element created: ${element.type} - "${element.value}" at ${element.offset}');
      }

      final panel = LayoutPanel(
        id: hivePanel.id,
        width: hivePanel.width,
        height: hivePanel.height,
        x: hivePanel.x,
        y: hivePanel.y,
        customText: hivePanel.customText,
        backgroundColor: Color(hivePanel.backgroundColorValue),
        previewImage: hivePanel.previewImage != null ? Uint8List.fromList(hivePanel.previewImage!) : null,
        elements: elements,
      );

      panels.add(panel);
      print('  Panel created with ${panel.elements.length} elements');
    }

    projectPages.add(panels);
  }

  final project = Project(
    id: model.id,
    name: model.name,
    createdAt: model.createdAt,
    lastModified: model.lastModified,
    thumbnail: model.thumbnail != null ? Uint8List.fromList(model.thumbnail!) : null,
    pages: projectPages,
  );

  print('Project created with ${project.pages.length} pages');

  // Final verification
  for (int pageIndex = 0; pageIndex < project.pages.length; pageIndex++) {
    final page = project.pages[pageIndex];
    print('Final verification - Page $pageIndex: ${page.length} panels');
    for (int panelIndex = 0; panelIndex < page.length; panelIndex++) {
      final panel = page[panelIndex];
      print('  Panel $panelIndex (${panel.id}): ${panel.elements.length} elements');
    }
  }

  return project;
}

