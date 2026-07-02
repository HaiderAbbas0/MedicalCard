class MedModel {
  final String name;
  final String strength;
  final String freq;
  final String dur;

  MedModel({
    required this.name,
    required this.strength,
    required this.freq,
    required this.dur,
  });

  factory MedModel.fromJson(Map<String, dynamic> json) {
    return MedModel(
      name: json['name'] as String,
      strength: json['strength'] as String,
      freq: json['freq'] as String,
      dur: json['dur'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'strength': strength,
      'freq': freq,
      'dur': dur,
    };
  }
}

class VisitModel {
  final String id;
  final String dx;
  final String doctor;
  final String specialty;
  final String hospital;
  final String dateLabel;
  final String time;
  final String symptoms;
  final String diagnosis;
  final String diagnosisNote;
  final List<MedModel> meds;
  final String followUp;
  final String advice;

  VisitModel({
    required this.id,
    required this.dx,
    required this.doctor,
    required this.specialty,
    required this.hospital,
    required this.dateLabel,
    required this.time,
    required this.symptoms,
    required this.diagnosis,
    required this.diagnosisNote,
    required this.meds,
    required this.followUp,
    required this.advice,
  });

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    final medsList = (json['meds'] as List? ?? [])
        .map((m) => MedModel.fromJson(m as Map<String, dynamic>))
        .toList();

    return VisitModel(
      id: json['id'] as String,
      dx: json['dx'] as String,
      doctor: json['doctor'] as String,
      specialty: json['specialty'] as String,
      hospital: json['hospital'] as String,
      dateLabel: json['dateLabel'] as String,
      time: json['time'] as String,
      symptoms: json['symptoms'] as String,
      diagnosis: json['diagnosis'] as String,
      diagnosisNote: json['diagnosisNote'] as String,
      meds: medsList,
      followUp: json['followUp'] as String,
      advice: json['advice'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dx': dx,
      'doctor': doctor,
      'specialty': specialty,
      'hospital': hospital,
      'dateLabel': dateLabel,
      'time': time,
      'symptoms': symptoms,
      'diagnosis': diagnosis,
      'diagnosisNote': diagnosisNote,
      'meds': meds.map((m) => m.toJson()).toList(),
      'followUp': followUp,
      'advice': advice,
    };
  }
}

class PrescriptionModel {
  final String id;
  final String name;
  final String strength;
  final String freq;
  final String dur;
  final String by;
  final String date;
  final bool active;
  final String? warn;
  // Dosing schedule (for reminders).
  final bool morning;
  final bool afternoon;
  final bool evening;
  final bool night;
  final int? durationDays;

  PrescriptionModel({
    required this.id,
    required this.name,
    required this.strength,
    required this.freq,
    required this.dur,
    required this.by,
    required this.date,
    required this.active,
    this.warn,
    this.morning = false,
    this.afternoon = false,
    this.evening = false,
    this.night = false,
    this.durationDays,
  });

  /// Dose labels enabled for this medication, in order.
  List<String> get doseLabels => [
        if (morning) 'morning',
        if (afternoon) 'afternoon',
        if (evening) 'evening',
        if (night) 'night',
      ];

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      strength: json['strength'] as String,
      freq: json['freq'] as String,
      dur: json['dur'] as String,
      by: json['by'] as String,
      date: json['date'] as String,
      active: json['active'] as bool,
      warn: json['warn'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'strength': strength,
      'freq': freq,
      'dur': dur,
      'by': by,
      'date': date,
      'active': active,
      'warn': warn,
    };
  }
}

class ReportModel {
  final String id;
  final String name;
  final String lab;
  final String date;
  final String status; // 'ready', 'reviewed', 'abnormal'
  final String specialty;

  ReportModel({
    required this.id,
    required this.name,
    required this.lab,
    required this.date,
    required this.status,
    this.specialty = 'Laboratory',
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      name: json['name'] as String,
      lab: json['lab'] as String,
      date: json['date'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lab': lab,
      'date': date,
      'status': status,
    };
  }
}
