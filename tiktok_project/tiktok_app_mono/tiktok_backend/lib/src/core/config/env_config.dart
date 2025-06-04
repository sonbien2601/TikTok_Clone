// tiktok_backend/lib/src/core/config/env_config.dart
import 'dart:io';        // Để đọc file
import 'dart:convert';   // Để decode JSON

class EnvConfig {
  static String? _mongoDbUri;
  static int? _serverPort;

  static Future<void> loadConfig() async {
    print('[EnvConfig] Starting to load configuration from config.json...');
    try {
      final configFile = File('config.json'); // File config.json ở thư mục gốc backend
      if (!await configFile.exists()) {
        final errorMessage = '[EnvConfig] CRITICAL: config.json file not found in the root of the backend project.';
        print(errorMessage);
        throw Exception(errorMessage);
      }

      final configString = await configFile.readAsString();
      if (configString.isEmpty) {
        final errorMessage = '[EnvConfig] CRITICAL: config.json file is empty.';
        print(errorMessage);
        throw Exception(errorMessage);
      }

      final Map<String, dynamic> configMap = jsonDecode(configString);
      print('[EnvConfig] config.json loaded and parsed successfully.');

      bool missingOrEmptyKeys = false;
      List<String> requiredKeys = ['MONGO_DB_URI', 'SERVER_PORT'];

      for (String keyName in requiredKeys) {
        if (!configMap.containsKey(keyName) || (configMap[keyName]?.toString().isEmpty ?? true)) {
          print('[EnvConfig] !!! CRITICAL: Configuration key "$keyName" is missing or empty in config.json !!!');
          missingOrEmptyKeys = true;
        }
      }

      if (missingOrEmptyKeys) {
        final errorMessage = '[EnvConfig] Please ensure all required configuration keys (MONGO_DB_URI, SERVER_PORT) are defined and have values in your config.json file.';
        print(errorMessage);
        throw Exception(errorMessage);
      }

      _mongoDbUri = configMap['MONGO_DB_URI'] as String?;
      String? serverPortStr = configMap['SERVER_PORT']?.toString();
      
      if (serverPortStr != null && serverPortStr.isNotEmpty) {
        _serverPort = int.tryParse(serverPortStr);
      }
      
      if (_serverPort == null) {
          print('[EnvConfig] Warning: SERVER_PORT value "$serverPortStr" from config.json is invalid or missing. Defaulting to port 8080.');
          _serverPort = 8080;
      }
      
      if (_mongoDbUri == null || _mongoDbUri!.isEmpty) {
        // Điều này không nên xảy ra nếu MONGO_DB_URI là requiredKey và đã qua kiểm tra ở trên
        final errorMessage = '[EnvConfig] MONGO_DB_URI is effectively not set from config.json. Database connection will fail.';
        print(errorMessage);
        throw Exception(errorMessage);
      }
      // Che thông tin nhạy cảm khi log
      String safeMongoUriToLog = _mongoDbUri!.contains('@') ? _mongoDbUri!.substring(_mongoDbUri!.indexOf('@')) : _mongoDbUri!;
      print('[EnvConfig] Configuration processed. MONGO_DB_URI: ...$safeMongoUriToLog, SERVER_PORT: $_serverPort');

    } catch (e) {
      print('[EnvConfig] FATAL Error loading or parsing config.json: $e');
      throw Exception('Failed to load critical configuration from config.json. Server cannot start.');
    }
  }

  static String get mongoDbUri {
    if (_mongoDbUri == null || _mongoDbUri!.isEmpty) {
      throw Exception("[EnvConfig] EnvConfig.mongoDbUri accessed before loadConfig() was successfully called or MONGO_DB_URI is missing/empty.");
    }
    return _mongoDbUri!;
  }

  static int get serverPort {
    if (_serverPort == null) {
         throw Exception("[EnvConfig] EnvConfig.serverPort accessed before loadConfig() was successfully called.");
    }
    return _serverPort!; 
  }
}