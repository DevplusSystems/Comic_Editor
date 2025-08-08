import 'dart:convert';

import 'package:comic_editor/project_hive_model.dart';
import 'package:comic_editor/project_mapper.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'PanelLayoutEditorScreen.dart';
import 'PanelModel/Project.dart';
import 'package:hive/hive.dart';

import 'TestPanelLayoutEditorScreen.dart';

// final UI
class ProjectsListScreen extends StatefulWidget {
  @override
  _ProjectsListScreenState createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  List<Project> savedProjects = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  void _loadProjects() {
    final box = Hive.box<ProjectHiveModel>('drafts');

    final projects = box.values.map((hiveModel) {
      return fromHiveModel(hiveModel);
    }).toList();

    setState(() {
      savedProjects = projects;
    });
  }

  void _createNewProject() async {
    final name = await _showProjectNameDialog();
    if (name != null && name.isNotEmpty) {
      final newProject = Project(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        pages: [[]],
      );

      setState(() {
        savedProjects.insert(0, newProject);
      });

      _editProject(newProject);
    }
  }

  Future<String?> _showProjectNameDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Project'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Project Name',
            hintText: 'Enter project name...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  void _editProject(Project project) async {
    final result = await Navigator.push<Project>(
      context,
      MaterialPageRoute(
        builder: (context) => PanelLayoutEditorScreen(project: project),
      ),
    ).then((_) {
      // Reload drafts from Hive when coming back
      _loadProjects();
    });

    if (result != null) {
      setState(() {
        final index = savedProjects.indexWhere((p) => p.id == result.id);
        if (index != -1) {
          savedProjects[index] = result.copyWith(lastModified: DateTime.now());

          // Update in Hive too
          final box = Hive.box<ProjectHiveModel>('drafts');
          box.put(result.id, toHiveModel(result));
        }
      });
    }
  }

  void _viewProject(Project project) async {
    final result = await Navigator.push<Project>(
      context,
      MaterialPageRoute(
        builder: (context) => TestPanelLayoutEditorScreen(project: project),
      ),

      /*    MaterialPageRoute(
        builder: (context) => PanelLayoutEditorScreen(project: project),
      ),*/
    ).then((_) {
      // Reload drafts from Hive when coming back
      _loadProjects();
    });

    if (result != null) {
      setState(() {
        final index = savedProjects.indexWhere((p) => p.id == result.id);
        if (index != -1) {
          savedProjects[index] = result.copyWith(lastModified: DateTime.now());

          // Update in Hive too
          final box = Hive.box<ProjectHiveModel>('drafts');
          box.put(result.id, toHiveModel(result));
        }
      });
    }
  }

  void _deleteProject(Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final box = Hive.box<ProjectHiveModel>('drafts');
      await box.delete(project.id);

      setState(() {
        savedProjects.remove(project);
      });
    }
  }

  void _duplicateProject(Project project) {
    final duplicatedProject = Project(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${project.name} (Copy)',
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      pages: project.pages,
    );

    setState(() {
      savedProjects.insert(0, duplicatedProject);

      // Save duplicated project to Hive
      final box = Hive.box<ProjectHiveModel>('drafts');
      box.put(duplicatedProject.id, toHiveModel(duplicatedProject));
    });
  }

  String projectToJson(Project project) {
    return jsonEncode({
      'id': project.id,
      'name': project.name,
      'createdAt': project.createdAt.toIso8601String(),
      'lastModified': project.lastModified.toIso8601String(),
      'pages': project.pages
          .map((page) => page
              .map((panel) => {
                    'id': panel.id,
                    'x': panel.x,
                    'y': panel.y,
                    'width': panel.width,
                    'height': panel.height,
                    'customText': panel.customText,
                    'backgroundColor': panel.backgroundColor.value,
                  })
              .toList())
          .toList(),
    });
  }

  Future<File> generatePdf(Project project) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Text('Project: ${project.name}'),
          );
        },
      ),
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${project.name}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          /*child: CircleAvatar(
            backgroundImage: AssetImage('assets/images/profile_icon.jpg'),
            backgroundColor: Colors.transparent,
          Image.asset('assets/images/ic_notification.png')
          ),*/
        ),

        title: Text(
          'Comic Creator',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: savedProjects.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: savedProjects.length,
              itemBuilder: (context, index) {
                final project = savedProjects[index];
                return _buildProjectCard(project);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewProject,
        icon: Icon(Icons.add),
        label: Text('New Project'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No Projects Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create your first comic project',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewProject(project),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: project.thumbnail != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          project.thumbnail!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.image_outlined,
                        color: Colors.grey[400],
                        size: 30,
                      ),
              ),
              SizedBox(width: 16),

              // Project info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${project.pages.length} page${project.pages.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Modified ${_formatDate(project.lastModified)}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                icon: Icon(Icons.edit, color: Colors.grey[700]),
                onPressed: () {
                  _editProject(project);
                },
              ),
              // Actions menu
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _editProject(project);
                      break;
                      case 'duplicate':
                      _duplicateProject(project);
                      break;
                    /* case 'export':
                      _exportProject(project);
                      break;*/
                    case 'delete':
                      _deleteProject(project);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.black87, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy, color: Colors.black87, size: 20),
                        SizedBox(width: 8),
                        Text('Duplicate'),
                      ],
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],

              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays != 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours != 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes != 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}

