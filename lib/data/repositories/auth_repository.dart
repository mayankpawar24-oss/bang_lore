import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/activity_log_model.dart';
import '../services/activity_log_service.dart';

abstract class AuthRepository {
  Future<UserModel> login(String identifier, String password);
  Future<UserModel> register(String name, String email, String password, UserRole role);
  Future<UserModel> registerUser({
    required String name,
    required String password,
    required String phoneNumber,
    required UserRole role,
    String? email,
    String? abhaId,
  });
  Future<UserModel> loginAsPatient();
  Future<UserModel> loginAsDoctor();
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
  Stream<UserModel?> get authStateChanges;
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final Map<String, UserModel> _userCache = {};

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  @override
  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) {
        dev.log('[AUTH] User signed out', name: 'FirebaseAuthRepository');
        _userCache.clear();
        return null;
      }
      dev.log('[AUTH] User signed in: ${user.email} (${user.uid})', name: 'FirebaseAuthRepository');
      return _loadUserModel(user.uid);
    });
  }

  @override
  Future<UserModel> login(String identifier, String password) async {
    final trimmed = identifier.trim();
    dev.log('[AUTH] [AUTH LOGIN] Attempting login for $trimmed', name: 'FirebaseAuthRepository');

    String authEmail = trimmed;
    if (!trimmed.contains('@')) {
      // Input is a phone number
      final cleanPhone = trimmed.replaceAll(RegExp(r'[^\d+]'), '');
      final plainDigits = cleanPhone.replaceAll(RegExp(r'\D'), '');

      // Check if user has an associated custom email in Firestore
      try {
        final query = await _db.collection('users')
            .where('phoneNumber', isEqualTo: plainDigits)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          final existingEmail = data['email'] as String?;
          if (existingEmail != null && existingEmail.isNotEmpty && existingEmail.contains('@')) {
            authEmail = existingEmail;
          } else {
            authEmail = '$plainDigits@phone.continuum.health';
          }
        } else {
          authEmail = '$plainDigits@phone.continuum.health';
        }
      } catch (e) {
        dev.log('[AUTH] Note looking up user phone: $e', name: 'FirebaseAuthRepository');
        authEmail = '$plainDigits@phone.continuum.health';
      }
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
      final uid = credential.user!.uid;
      dev.log('[AUTH] [AUTH LOGIN] Firebase Auth success: $uid', name: 'FirebaseAuthRepository');
      return _loadUserModel(uid);
    } catch (e) {
      dev.log('[AUTH] Login failure: $e', error: e, name: 'FirebaseAuthRepository');
      rethrow;
    }
  }

  @override
  Future<UserModel> register(
      String name, String email, String password, UserRole role) {
    return registerUser(
      name: name,
      password: password,
      phoneNumber: '9876543210',
      role: role,
      email: email,
    );
  }

  @override
  Future<UserModel> registerUser({
    required String name,
    required String password,
    required String phoneNumber,
    required UserRole role,
    String? email,
    String? abhaId,
  }) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final hasEmail = email != null && email.trim().isNotEmpty && email.contains('@');
    final hasAbha = abhaId != null && abhaId.trim().isNotEmpty;

    // Use email if provided, otherwise deterministic phone identity
    final authEmail = hasEmail ? email.trim().toLowerCase() : '$cleanPhone@phone.continuum.health';

    dev.log('[AUTH] Registering $name with phone $cleanPhone (email: $authEmail, role: ${role.name})', name: 'FirebaseAuthRepository');

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
      final uid = credential.user!.uid;
      dev.log('[AUTH] Firebase Auth account created: $uid', name: 'FirebaseAuthRepository');

      final user = UserModel(
        id: uid,
        name: name.trim(),
        email: hasEmail ? email.trim().toLowerCase() : '',
        role: role,
        phoneNumber: cleanPhone,
        phone: cleanPhone,
        abhaId: hasAbha ? abhaId.trim() : null,
      );

      _userCache[uid] = user;

      // 1. Write users/{uid} document
      dev.log('[FIRESTORE] Writing users/$uid (role: ${role.name})', name: 'FirebaseAuthRepository');
      final userDoc = <String, dynamic>{
        'uid': uid,
        'name': name.trim(),
        'phoneNumber': cleanPhone,
        'phone': cleanPhone,
        'role': role.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (hasEmail) userDoc['email'] = email.trim().toLowerCase();
      if (hasAbha) userDoc['abhaId'] = abhaId.trim();

      await _db.collection('users').doc(uid).set(userDoc, SetOptions(merge: true));
      dev.log('[FIRESTORE] users/$uid created successfully', name: 'FirebaseAuthRepository');

      // 2. Write role-specific profile document
      if (role == UserRole.patient) {
        dev.log('[FIRESTORE] Writing patients/$uid', name: 'FirebaseAuthRepository');
        final patientDoc = <String, dynamic>{
          'name': name.trim(),
          'uid': uid,
          'phoneNumber': cleanPhone,
          'phone': cleanPhone,
          'age': 30,
          'condition': 'General Care',
          'status': 'discharged',
          'medicationAdherence': 100.0,
          'isAuthorized': false,
          'conditions': [],
          'medicalHistory': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (hasEmail) patientDoc['email'] = email.trim().toLowerCase();
        if (hasAbha) patientDoc['abhaId'] = abhaId.trim();

        await _db.collection('patients').doc(uid).set(patientDoc, SetOptions(merge: true));
      } else {
        dev.log('[FIRESTORE] Writing doctors/$uid', name: 'FirebaseAuthRepository');
        final doctorDoc = <String, dynamic>{
          'name': name.trim(),
          'uid': uid,
          'phoneNumber': cleanPhone,
          'phone': cleanPhone,
          'specialty': 'General Practice',
          'hospital': 'City Clinic',
          'rating': 5.0,
          'distance': 0.0,
          'avatarUrl': '',
          'about': 'Healthcare Practitioner',
          'availableDays': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (hasEmail) doctorDoc['email'] = email.trim().toLowerCase();
        if (hasAbha) doctorDoc['abhaId'] = abhaId.trim();

        await _db.collection('doctors').doc(uid).set(doctorDoc, SetOptions(merge: true));
      }

      try {
        final activityService = ActivityLogService(db: _db, auth: _auth);
        await activityService.logEvent(
          patientId: role == UserRole.patient ? uid : null,
          doctorId: role == UserRole.doctor ? uid : null,
          eventType: role == UserRole.patient ? ActivityEventType.patientCreated : ActivityEventType.general,
          title: role == UserRole.patient ? 'Patient Account Created' : 'Doctor Account Created',
          description: 'Account registered successfully for ${name.trim()} (${role.name}).',
          actorUid: uid,
          actorRole: role.name,
          actorName: name.trim(),
        );
      } catch (e) {
        dev.log('[AUTH] Activity log note during registration: $e', name: 'FirebaseAuthRepository');
      }

      dev.log('[AUTH] Registration complete for $uid', name: 'FirebaseAuthRepository');
      return user;
    } catch (e, st) {
      dev.log('[AUTH] Registration error: $e', error: e, stackTrace: st, name: 'FirebaseAuthRepository');
      rethrow;
    }
  }

  @override
  Future<UserModel> loginAsPatient() async {
    const email = 'patient.demo@ardius.care';
    const password = 'DemoPassword123!';
    try {
      return await login(email, password);
    } catch (_) {
      try {
        return await register('Margaret Chen (Demo)', email, password, UserRole.patient);
      } catch (_) {
        return await login(email, password);
      }
    }
  }

  @override
  Future<UserModel> loginAsDoctor() async {
    const email = 'doctor.demo@ardius.care';
    const password = 'DemoPassword123!';
    try {
      return await login(email, password);
    } catch (_) {
      try {
        return await register('Dr. Aisha Patel (Demo)', email, password, UserRole.doctor);
      } catch (_) {
        return await login(email, password);
      }
    }
  }

  @override
  Future<void> logout() async {
    dev.log('[AUTH] logout started', name: 'FirebaseAuthRepository');
    _userCache.clear();
    await _auth.signOut();
    dev.log('[AUTH] Firebase signOut completed: currentUser=${_auth.currentUser}', name: 'FirebaseAuthRepository');
    dev.log('[AUTH] logout state cleared', name: 'FirebaseAuthRepository');
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _loadUserModel(user.uid);
  }

  Future<UserModel> _loadUserModel(String uid) async {
    if (_userCache.containsKey(uid)) {
      dev.log('[AUTH LOAD] Returning cached user model for $uid (role: ${_userCache[uid]?.role.name})', name: 'FirebaseAuthRepository');
      return _userCache[uid]!;
    }

    dev.log('[AUTH LOAD] Fetching users/$uid from Firestore', name: 'FirebaseAuthRepository');
    final docRef = _db.collection('users').doc(uid);
    DocumentSnapshot doc = await docRef.get();

    // Retry up to 3 times in case of write latency right after registration
    int retries = 0;
    while (!doc.exists && retries < 3) {
      retries++;
      dev.log('[AUTH LOAD] users/$uid not found, retrying ($retries/3)...', name: 'FirebaseAuthRepository');
      await Future.delayed(const Duration(milliseconds: 250));
      doc = await docRef.get();
    }

    if (!doc.exists) {
      dev.log('[AUTH LOAD] users/$uid doc does not exist, creating default patient profile', name: 'FirebaseAuthRepository');
      final authUser = _auth.currentUser;
      if (authUser != null) {
        final email = authUser.email ?? '';
        final name = authUser.displayName?.isNotEmpty == true
            ? authUser.displayName!
            : (email.isNotEmpty ? email.split('@').first : 'User');
        final user = UserModel(
          id: uid,
          name: name,
          email: email,
          role: UserRole.patient,
        );
        await docRef.set(user.toFirestoreCreate(), SetOptions(merge: true));

        await _db.collection('patients').doc(uid).set({
          'name': name,
          'uid': uid,
          'age': 30,
          'condition': 'General Care',
          'status': 'stable',
          'medicationAdherence': 100.0,
          'isAuthorized': false,
          'conditions': [],
          'medicalHistory': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        doc = await docRef.get();
      }
    }

    if (!doc.exists || doc.data() == null) {
      dev.log('[AUTH ERROR] Document users/$uid could not be loaded', name: 'FirebaseAuthRepository');
      throw Exception('User record users/$uid does not exist in Firestore.');
    }

    final data = doc.data() as Map<String, dynamic>;
    if (!data.containsKey('role') || data['role'] == null) {
      dev.log('[AUTH ERROR] Document users/$uid missing role field', name: 'FirebaseAuthRepository');
      throw Exception('User profile users/$uid is missing role assignment.');
    }

    final userModel = UserModel.fromFirestore(doc);
    _userCache[uid] = userModel;
    dev.log('[AUTH LOAD] Successfully loaded users/$uid with role=${userModel.role.name}', name: 'FirebaseAuthRepository');
    return userModel;
  }
}
