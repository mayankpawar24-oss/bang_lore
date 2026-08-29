class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String hospital;
  final double rating;
  final double distance;
  final String avatarUrl;
  final String phone;
  final String about;
  final List<String> availableDays;
  final bool isAvailable;

  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.hospital,
    required this.rating,
    required this.distance,
    required this.avatarUrl,
    required this.phone,
    required this.about,
    required this.availableDays,
    required this.isAvailable,
  });

  Doctor copyWith({
    String? id,
    String? name,
    String? specialty,
    String? hospital,
    double? rating,
    double? distance,
    String? avatarUrl,
    String? phone,
    String? about,
    List<String>? availableDays,
    bool? isAvailable,
  }) {
    return Doctor(
      id: id ?? this.id,
      name: name ?? this.name,
      specialty: specialty ?? this.specialty,
      hospital: hospital ?? this.hospital,
      rating: rating ?? this.rating,
      distance: distance ?? this.distance,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      about: about ?? this.about,
      availableDays: availableDays ?? this.availableDays,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialty': specialty,
      'hospital': hospital,
      'rating': rating,
      'distance': distance,
      'avatarUrl': avatarUrl,
      'phone': phone,
      'about': about,
      'availableDays': availableDays,
      'isAvailable': isAvailable,
    };
  }

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'] as String,
      name: json['name'] as String,
      specialty: json['specialty'] as String,
      hospital: json['hospital'] as String,
      rating: (json['rating'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      avatarUrl: json['avatarUrl'] as String,
      phone: json['phone'] as String,
      about: json['about'] as String,
      availableDays: List<String>.from(json['availableDays']),
      isAvailable: json['isAvailable'] as bool,
    );
  }
}

typedef DoctorModel = Doctor;
