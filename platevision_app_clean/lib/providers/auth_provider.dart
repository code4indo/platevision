import 'package:flutter/foundation.dart';
import 'package:platevision_ai/models/user.dart';
import 'package:platevision_ai/services/api_service.dart';
import 'package:platevision_ai/services/storage_service.dart';

// ============================================================================
// Auth State Enum
// ============================================================================

/// Represents the current authentication state.
enum AuthState {
  authenticated,
  unauthenticated,
  loading,
}

// ============================================================================
// Auth Provider
// ============================================================================

/// Provider for managing authentication state.
///
/// Currently uses mock authentication for development/demo purposes.
/// Prepared for future integration with real authentication (JWT, OAuth, etc.).
class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;

  // --- State ---
  AuthState _authState = AuthState.unauthenticated;
  User? _currentUser;
  String? _errorMessage;

  // --- Getters ---
  AuthState get authState => _authState;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => _authState == AuthState.authenticated;

  /// Whether authentication is in progress.
  bool get isLoading => _authState == AuthState.loading;

  /// Whether there is an auth error to display.
  bool get hasError => _errorMessage != null;

  /// Returns the current user's role, or null if not authenticated.
  UserRole? get userRole => _currentUser?.role;

  /// Returns the current user's full name, or empty string.
  String get userFullName => _currentUser?.fullName ?? '';

  /// Returns the current user's initials, or empty string.
  String get userInitials => _currentUser?.initials ?? '';

  /// Returns the current user's role label, or empty string.
  String get userRoleLabel => _currentUser?.roleLabel ?? '';

  // --- Constructor ---

  AuthProvider({
    required ApiService apiService,
    required StorageService storageService,
  })  : _apiService = apiService,
        _storageService = storageService {
    _tryRestoreSession();
  }

  // --------------------------------------------------------------------------
  // Session Restoration
  // --------------------------------------------------------------------------

  /// Attempts to restore a previous session from local storage.
  Future<void> _tryRestoreSession() async {
    if (_storageService.hasAuthToken && _storageService.userId != null) {
      _authState = AuthState.loading;
      notifyListeners();

      try {
        // Set the API token
        _apiService.setAuthToken(_storageService.authToken!);

        // For now, restore from stored data (mock)
        // In production, this would validate the token with the server
        final roleStr = _storageService.userRole ?? 'viewer';
        final role = _parseRole(roleStr);

        _currentUser = User(
          id: _storageService.userId ?? '',
          username: _storageService.username ?? '',
          fullName: _storageService.username ?? 'Pengguna',
          email: '${_storageService.username ?? 'user'}@platevision.ai',
          role: role,
          laboratory: 'Lab Mikrobiologi',
          lastLogin: DateTime.now(),
          isActive: true,
        );

        _authState = AuthState.authenticated;
        _errorMessage = null;
      } catch (_) {
        // Session restoration failed, clear auth data
        await _storageService.clearAuthData();
        _apiService.clearAuthToken();
        _authState = AuthState.unauthenticated;
      }

      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // Login
  // --------------------------------------------------------------------------

  /// Attempts to log in with the given credentials.
  ///
  /// Currently uses mock authentication. The following demo accounts are available:
  /// - admin / admin123 -> UserRole.admin
  /// - supervisor / super123 -> UserRole.supervisor
  /// - analyst / analyst123 -> UserRole.analyst
  /// - Any other credentials -> UserRole.viewer
  Future<void> login({
    required String username,
    required String password,
  }) async {
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 800));

      // Mock authentication logic
      final user = _mockAuthenticate(username, password);

      if (user != null) {
        _currentUser = user;
        _authState = AuthState.authenticated;

        // Save to storage
        await _saveSession(user, 'mock_token_${user.id}');
      } else {
        _errorMessage =
            'Username atau password salah. Silakan coba lagi.';
        _authState = AuthState.unauthenticated;
      }
    } catch (e) {
      _errorMessage = 'Gagal masuk: ${e.toString()}';
      _authState = AuthState.unauthenticated;
    }

    notifyListeners();
  }

  /// Performs mock authentication against hardcoded demo accounts.
  User? _mockAuthenticate(String username, String password) {
    // Demo accounts for development
    final accounts = <String, _MockAccount>{
      'admin': _MockAccount(
        password: 'admin123',
        user: User(
          id: 'USR-001',
          username: 'admin',
          fullName: 'Dr. Administrator',
          email: 'admin@platevision.ai',
          role: UserRole.admin,
          laboratory: 'Lab Mikrobiologi Pusat',
          lastLogin: DateTime.now(),
          isActive: true,
        ),
      ),
      'supervisor': _MockAccount(
        password: 'super123',
        user: User(
          id: 'USR-002',
          username: 'supervisor',
          fullName: 'Ir. Siti Nurhaliza',
          email: 'supervisor@platevision.ai',
          role: UserRole.supervisor,
          laboratory: 'Lab Mikrobiologi Pusat',
          lastLogin: DateTime.now(),
          isActive: true,
        ),
      ),
      'analyst': _MockAccount(
        password: 'analyst123',
        user: User(
          id: 'USR-003',
          username: 'analyst',
          fullName: 'Ahmad Fauzi, S.Si',
          email: 'analyst@platevision.ai',
          role: UserRole.analyst,
          laboratory: 'Lab Mikrobiologi Pusat',
          lastLogin: DateTime.now(),
          isActive: true,
        ),
      ),
      'viewer': _MockAccount(
        password: 'viewer123',
        user: User(
          id: 'USR-004',
          username: 'viewer',
          fullName: 'Budi Santoso',
          email: 'viewer@platevision.ai',
          role: UserRole.viewer,
          laboratory: 'Lab Mikrobiologi Pusat',
          lastLogin: DateTime.now(),
          isActive: true,
        ),
      ),
    };

    final account = accounts[username.toLowerCase()];
    if (account != null && account.password == password) {
      return account.user;
    }

    // Allow any username/password combo with viewer role for demo
    if (username.isNotEmpty && password.isNotEmpty) {
      return User(
        id: 'USR-DEMO-${DateTime.now().millisecondsSinceEpoch}',
        username: username,
        fullName: username,
        email: '$username@platevision.ai',
        role: UserRole.viewer,
        laboratory: 'Lab Demo',
        lastLogin: DateTime.now(),
        isActive: true,
      );
    }

    return null;
  }

  // --------------------------------------------------------------------------
  // Logout
  // --------------------------------------------------------------------------

  /// Logs out the current user and clears session data.
  Future<void> logout() async {
    _authState = AuthState.loading;
    notifyListeners();

    try {
      // Clear API token
      _apiService.clearAuthToken();

      // Clear stored session data
      await _storageService.clearAuthData();

      // Reset state
      _currentUser = null;
      _errorMessage = null;
      _authState = AuthState.unauthenticated;
    } catch (_) {
      // Force logout even if clearing storage fails
      _currentUser = null;
      _errorMessage = null;
      _authState = AuthState.unauthenticated;
    }

    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Session Persistence
  // --------------------------------------------------------------------------

  /// Saves the current session to local storage.
  Future<void> _saveSession(User user, String token) async {
    await Future.wait([
      _storageService.saveAuthToken(token),
      _storageService.saveUserId(user.id),
      _storageService.saveUsername(user.username),
      _storageService.saveUserRole(user.role.name),
    ]);

    // Set API token for future requests
    _apiService.setAuthToken(token);
  }

  // --------------------------------------------------------------------------
  // User Profile Updates
  // --------------------------------------------------------------------------

  /// Updates the current user's profile information.
  void updateProfile({
    String? fullName,
    String? email,
    String? laboratory,
  }) {
    if (_currentUser == null) return;

    _currentUser = _currentUser!.copyWith(
      fullName: fullName,
      email: email,
      laboratory: laboratory,
    );

    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Error Handling
  // --------------------------------------------------------------------------

  /// Clears the current auth error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Utility
  // --------------------------------------------------------------------------

  /// Parses a role string into UserRole enum.
  UserRole _parseRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return UserRole.admin;
      case 'supervisor':
        return UserRole.supervisor;
      case 'analyst':
      case 'analis':
        return UserRole.analyst;
      case 'viewer':
        return UserRole.viewer;
      default:
        return UserRole.viewer;
    }
  }
}

// ============================================================================
// Mock Account Helper
// ============================================================================

/// Helper class for mock account storage.
class _MockAccount {
  final String password;
  final User user;

  const _MockAccount({
    required this.password,
    required this.user,
  });
}
