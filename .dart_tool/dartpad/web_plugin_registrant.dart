// Flutter web plugin registrant file.
//
// Generated file. Do not edit.
//

// @dart = 2.13
// ignore_for_file: type=lint

<<<<<<< HEAD
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_messaging_web/firebase_messaging_web.dart';
=======
import 'package:device_info_plus/src/device_info_plus_web.dart';
>>>>>>> 953101cc20f75a44998cc662775dbfadcdaf6562
import 'package:permission_handler_html/permission_handler_html.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void registerPlugins([final Registrar? pluginRegistrar]) {
  final Registrar registrar = pluginRegistrar ?? webPluginRegistrar;
<<<<<<< HEAD
  FirebaseCoreWeb.registerWith(registrar);
  FirebaseMessagingWeb.registerWith(registrar);
=======
  DeviceInfoPlusWebPlugin.registerWith(registrar);
>>>>>>> 953101cc20f75a44998cc662775dbfadcdaf6562
  WebPermissionHandler.registerWith(registrar);
  SharedPreferencesPlugin.registerWith(registrar);
  registrar.registerMessageHandler();
}
