import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// IP Selector utility for automatic IP assignment from 10.66.66.0/24 subnet
/// Handles candidate generation, persistence, and collision detection retries
class IpSelector {
  static const String _prefKeyLastIp = 'vpn_last_assigned_ip';
  static const String _prefKeyLastUsedIpIndex = 'vpn_last_used_ip_index';
  static const int _minIp = 2; // 10.66.66.2
  static const int _maxIp = 254; // 10.66.66.254
  static const int _subnetPrefix = 32;
  
  /// Generate candidate IP addresses in order (10.66.66.2 to 10.66.66.254)
  static List<String> _generateCandidateIps() {
    final candidates = <String>[];
    for (int i = _minIp; i <= _maxIp; i++) {
      candidates.add('10.66.66.$i/$_subnetPrefix');
    }
    return candidates;
  }
  
  /// Get the initial candidate IP to try
  /// Tries saved IP first, then falls back to sequential starting from saved index
  static Future<String> getInitialCandidateIp() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Try saved IP first
    final savedIp = prefs.getString(_prefKeyLastIp);
    if (savedIp != null && _isValidCandidateIp(savedIp)) {
      return savedIp;
    }
    
    // Fall back to first candidate (10.66.66.2)
    return '10.66.66.$_minIp/$_subnetPrefix';
  }
  
  /// Get next candidate IP in sequence
  /// Optionally randomizes starting point to reduce collisions
  static Future<String> getNextCandidateIp(String currentIp, {bool randomize = false}) async {
    final candidates = _generateCandidateIps();
    
    // Find current IP index
    int currentIndex = candidates.indexOf(currentIp);
    if (currentIndex == -1) {
      // Current IP not in candidates, start from beginning
      currentIndex = -1;
    }
    
    int nextIndex = currentIndex + 1;
    
    // If randomize is enabled and we're starting fresh, pick random starting point
    if (randomize && currentIndex == -1) {
      final random = Random();
      nextIndex = random.nextInt(candidates.length);
    }
    
    // Wrap around if we've exhausted all candidates
    if (nextIndex >= candidates.length) {
      nextIndex = 0;
    }
    
    return candidates[nextIndex];
  }
  
  /// Save successfully assigned IP
  static Future<void> saveAssignedIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyLastIp, ip);
    
    // Also save the index for faster sequential lookup
    final candidates = _generateCandidateIps();
    final index = candidates.indexOf(ip);
    if (index != -1) {
      await prefs.setInt(_prefKeyLastUsedIpIndex, index);
    }
  }
  
  /// Clear saved IP (e.g., on disconnect or reset)
  static Future<void> clearSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyLastIp);
    await prefs.remove(_prefKeyLastUsedIpIndex);
  }
  
  /// Check if IP is a valid candidate
  static bool _isValidCandidateIp(String ip) {
    if (!ip.endsWith('/$_subnetPrefix')) {
      return false;
    }
    
    final ipPart = ip.split('/').first;
    if (!ipPart.startsWith('10.66.66.')) {
      return false;
    }
    
    final lastOctet = int.tryParse(ipPart.split('.').last);
    if (lastOctet == null || lastOctet < _minIp || lastOctet > _maxIp) {
      return false;
    }
    
    return true;
  }
  
  /// Get all candidate IPs (for testing/debugging)
  static List<String> getAllCandidateIps() {
    return _generateCandidateIps();
  }
}
