import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> login(String email, String password);
  Future<UserModel> register(String name, String email, String password, UserRole role);
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
        dev.log('[AUTH STREAM] User signed out', name: 'FirebaseAuthRepository');
        _userCache.clear();
        return null;
      }
      dev.log('[AUTH STREAM] User signed in: ${user.email} (${user.uid})', name: 'FirebaseAuthRepository');
      return _loadUserModel(user.uid);
    });
  }

  @override
  Future<UserModel> login(String email, String password) async {
    dev.log('[AUTH LOGIN] Attempting login for $email', name: 'FirebaseAuthRepository');
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;
    dev.log('[AUTH LOGIN] Firebase Auth success: $uid', name: 'FirebaseAuthRepository');
    return _loadUserModel(uid);
  }

  @override
  Future<UserModel> register(
      String name, String email, String password, UserRole role) async {
    dev.log('[DOCTOR AUTH] Registering $email as ${role.name}', name: 'FirebaseAuthRepository');
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;
    dev.log('[DOCTOR AUTH] Firebase Auth account created for $uid', name: 'FirebaseAuthRepository');

    final user = UserModel(
      id: uid,
      name: name.trim(),
      email: email.trim(),
      role: role,
    );

    // Cache user model immediately to prevent race conditions during authStateChanges
    _userCache[uid] = user;

    // 1. Write users/{uid} document
    dev.log('[FIRESTORE] Writing users/$uid to Firestore (role: ${role.name})', name: 'FirebaseAuthRepository');
    await _db.collection('users').doc(uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'role': role.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    dev.log('[FIRESTORE] users/$uid created successfully', name: 'FirebaseAuthRepository');

    // 2. Write role-specific profile document
    if (role == UserRole.patient) {
      dev.log('[FIRESTORE] Writing patients/$uid to Firestore', name: 'FirebaseAuthRepository');
      await _db.collection('patients').doc(uid).set({
        'name': name.trim(),
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
      });
    } else {
      dev.log('[DOCTOR AUTH] [FIRESTORE] Writing doctors/$uid to Firestore', name: 'FirebaseAuthRepository');
      await _db.collection('doctors').doc(uid).set({
        'name': name.trim(),
        'uid': uid,
        'specialty': 'General Practice',
        'hospital': 'City Clinic',
        'rating': 5.0,
        'distance': 0.0,
        'avatarUrl': '',
        'phone': '',
        'about': 'Healthcare Practitioner',
        'availableDays': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    dev.log('[DOCTOR AUTH] Registration complete for $uid', name: 'FirebaseAuthRepository');
    return user;
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
    dev.log('[LOGOUT] logout started', name: 'FirebaseAuthRepository');
    _userCache.clear();
    await _auth.signOut();
    dev.log('[LOGOUT] Firebase signOut completed: currentUser=${_auth.currentUser}', name: 'FirebaseAuthRepository');
    dev.log('[LOGOUT] logout state cleared', name: 'FirebaseAuthRepository');
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
