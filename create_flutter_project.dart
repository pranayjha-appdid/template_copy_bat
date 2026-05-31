import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print(
        'Usage: dart create_flutter_project.dart project_name flutter_version org_name');
    print('Example: dart create_flutter_project.dart ecommerce_app 3.35.7 com');
    print(
        'Example: dart create_flutter_project.dart grocery_app 3.35.7 com.examplecompany');
    exit(1);
  }

  final projectName = args[0];
  final flutterVersion = args[1];
  final orgName = args.length >= 3 ? args[2] : 'com';

  const templateRepo =
      'https://github.com/Akash-appdid/flutter-new-updated-getx-template.git';

  final tempDir = Directory.systemTemp.createTempSync('flutter_template_');

  try {
    await checkCommand('fvm');
    await checkCommand('git');

    print('\nInstalling Flutter $flutterVersion using FVM...');
    await runCommand('fvm', ['install', flutterVersion]);

    final projectDir = Directory(projectName);
    if (projectDir.existsSync()) {
      print('Error: Folder "$projectName" already exists.');
      exit(1);
    }

    print('\nCreating fresh Flutter project...');
    print('Project name: $projectName');
    print('Flutter version: $flutterVersion');
    print('Org: $orgName');

    await runCommand('fvm', [
      'spawn',
      flutterVersion,
      'create',
      '--org',
      orgName,
      projectName,
    ]);

    print('\nCloning template repo into temp folder...');
    await runCommand('git', [
      'clone',
      '--depth',
      '1',
      templateRepo,
      tempDir.path,
    ]);

    print('\nCopying lib folder...');
    final targetLib = Directory('$projectName/lib');
    if (targetLib.existsSync()) {
      targetLib.deleteSync(recursive: true);
    }
    await copyDirectory(
      Directory('${tempDir.path}/lib'),
      Directory('$projectName/lib'),
    );

    print('\nCopying assets folder...');
    final targetAssets = Directory('$projectName/assets');
    if (targetAssets.existsSync()) {
      targetAssets.deleteSync(recursive: true);
    }
    await copyDirectory(
      Directory('${tempDir.path}/assets'),
      Directory('$projectName/assets'),
    );

    print('\nCopying analysis_options.yaml...');
    final templateAnalysis = File('${tempDir.path}/analysis_options.yaml');
    if (templateAnalysis.existsSync()) {
      templateAnalysis.copySync('$projectName/analysis_options.yaml');
    }

    print('\nReplacing pubspec dependencies section from template...');
    await replacePubspecDependencies(
      projectName: projectName,
      projectPubspecPath: '$projectName/pubspec.yaml',
      templatePubspecPath: '${tempDir.path}/pubspec.yaml',
    );

    print('\nReplacing old package imports...');
    await replacePackageImports(
      Directory('$projectName/lib'),
      oldPackageName: 'relief_app',
      newPackageName: projectName,
    );

    print('\nSetting FVM version inside project...');
    await runCommand(
      'fvm',
      ['use', flutterVersion, '--force'],
      workingDirectory: projectName,
    );

    print('\nRunning pub get...');
    await runCommand(
      'fvm',
      ['flutter', 'pub', 'get'],
      workingDirectory: projectName,
    );

    print('\nCleaning temp files...');
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }

    print('\nDone!');
    print('Project created: $projectName');
    print('Flutter version: $flutterVersion');
    print('Application ID should be: $orgName.$projectName');
  } catch (e) {
    print('\nError: $e');

    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }

    exit(1);
  }
}

Future<void> checkCommand(String command) async {
  final result = await Process.run(
    Platform.isWindows ? 'where' : 'which',
    [command],
    runInShell: true,
  );

  if (result.exitCode != 0) {
    throw '$command not found. Please install/check $command first.';
  }
}

Future<void> runCommand(
  String command,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final process = await Process.start(
    command,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
  );

  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);

  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    throw 'Command failed: $command ${arguments.join(' ')}';
  }
}

Future<void> copyDirectory(Directory source, Directory destination) async {
  if (!source.existsSync()) {
    throw 'Source folder not found: ${source.path}';
  }

  if (destination.existsSync()) {
    destination.deleteSync(recursive: true);
  }

  destination.createSync(recursive: true);

  if (Platform.isWindows) {
    final result = await Process.start(
      'robocopy',
      [
        source.absolute.path,
        destination.absolute.path,
        '/E',
      ],
      runInShell: true,
    );

    stdout.addStream(result.stdout);
    stderr.addStream(result.stderr);

    final exitCode = await result.exitCode;

    // Robocopy success codes are 0 to 7.
    if (exitCode > 7) {
      throw 'Failed to copy folder: ${source.path}';
    }
  } else {
    final result = await Process.start(
      'cp',
      [
        '-R',
        '${source.absolute.path}/.',
        destination.absolute.path,
      ],
      runInShell: true,
    );

    stdout.addStream(result.stdout);
    stderr.addStream(result.stderr);

    final exitCode = await result.exitCode;

    if (exitCode != 0) {
      throw 'Failed to copy folder: ${source.path}';
    }
  }
}

Future<void> replacePubspecDependencies({
  required String projectName,
  required String projectPubspecPath,
  required String templatePubspecPath,
}) async {
  final projectPubspec = File(projectPubspecPath);
  final templatePubspec = File(templatePubspecPath);

  if (!projectPubspec.existsSync()) {
    throw 'Project pubspec.yaml not found';
  }

  if (!templatePubspec.existsSync()) {
    throw 'Template pubspec.yaml not found';
  }

  var projectText = projectPubspec.readAsStringSync();
  final templateText = templatePubspec.readAsStringSync();

  projectText = projectText.replaceFirst(
    RegExp(r'^name:\s*.*$', multiLine: true),
    'name: $projectName',
  );

  final projectTop = projectText
      .replaceFirst(
        RegExp(r'^dependencies:\s*.*$', multiLine: true, dotAll: true),
        '',
      )
      .trimRight();

  final templateDependenciesMatch = RegExp(
    r'^dependencies:\s*.*$',
    multiLine: true,
    dotAll: true,
  ).firstMatch(templateText);

  if (templateDependenciesMatch == null) {
    throw 'Template dependencies section not found';
  }

  final templateFromDependencies =
      templateDependenciesMatch.group(0)!.trimRight();

  final finalText = '$projectTop\n\n$templateFromDependencies\n';

  projectPubspec.writeAsStringSync(finalText);
}

Future<void> replacePackageImports(
  Directory libDir, {
  required String oldPackageName,
  required String newPackageName,
}) async {
  if (!libDir.existsSync()) {
    throw 'lib folder not found';
  }

  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = entity.readAsStringSync();

      final updatedContent = content.replaceAll(
        'package:$oldPackageName/',
        'package:$newPackageName/',
      );

      if (content != updatedContent) {
        entity.writeAsStringSync(updatedContent);
      }
    }
  }
}
