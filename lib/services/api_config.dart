class ApiConfig {
  // Production URL
  static const String productionUrl = 'https://sehatid-backend-production.up.railway.app/api';

  // Local IP Options
  static const String localEthernetUrl = 'http://192.168.56.1:3000/api'; // Host-only adapter (requested)
  static const String localWifiUrl = 'http://${const String.fromEnvironment('WIFI_IP', defaultValue: '192.168.1.100')}:3000/api'; // Active Wi-Fi adapter

  // Active Base URL
  // Defaulting to the requested host-only adapter. Switch to localWifiUrl if testing from a physical phone.
  static const String baseUrl = localWifiUrl;
}
