// NOTE: This file is NOT USED. The live backend URL lives in
// lib/services/api_service.dart (the `base`/`baseUrl` constant). Edit it there.

class Config {
  // ── Change this to your Render URL once deployed ──────────────
  // Example: 'https://lexnland-backend.onrender.com'
  // For local testing on real device: 'http://192.168.x.x:5000'
  // For emulator testing: 'http://10.0.2.2:5000'

  static const serverUrl = 'http://localhost:5000';
  //static const serverUrl = 'https://lexnland-backend.onrender.com';
  static const apiUrl = '$serverUrl/api';
  static const socketUrl = serverUrl;
}