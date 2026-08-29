import '../models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> login(String email, String password);
  Future<UserModel> loginAsPatient();
  Future<UserModel> loginAsDoctor();
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
}

class MockAuthRepository implements AuthRepository {
  UserModel? _currentUser;

  @override
  Future<UserModel> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = const UserModel(
      id: 'p_margaret_01',
      name: 'Margaret Chen',
      email: 'margaret@example.com',
      role: UserRole.patient,
    );
    return _currentUser!;
  }

  @override
  Future<UserModel> loginAsPatient() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = const UserModel(
      id: 'p_margaret_01',
      name: 'Margaret Chen',
      email: 'margaret@example.com',
      role: UserRole.patient,
    );
    return _currentUser!;
  }

  @override
  Future<UserModel> loginAsDoctor() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = const UserModel(
      id: 'd_aisha_01',
      name: 'Dr. Aisha Patel',
      email: 'aisha@example.com',
      role: UserRole.doctor,
    );
    return _currentUser!;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    return _currentUser;
  }
}
