// lib/config/app_config.dart

enum OdooEnvironment { pruebas, produccion }

class AppConfig {
  // Cambiar este valor según el entorno
  static const OdooEnvironment currentEnvironment = OdooEnvironment.pruebas;

  // Configuración por entorno
  static String get baseUrl {
    switch (currentEnvironment) {
      case OdooEnvironment.pruebas:
        return "https://pruebas-aplicacion.odoo.com";
      case OdooEnvironment.produccion:
        return "https://produccion-aplicacion.odoo.com";
    }
  }

  static String get dbName {
    switch (currentEnvironment) {
      case OdooEnvironment.pruebas:
        return "pruebas-aplicacion";
      case OdooEnvironment.produccion:
        return "produccion-aplicacion";
    }
  }

  // Timeout global para peticiones HTTP
  static const int httpTimeoutSeconds = 30;

  // Configuración adicional futura
  static bool debugMode = true; // Para logs internos
}
