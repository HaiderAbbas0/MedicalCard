import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════
//  Patient
// ═══════════════════════════════════════════════════════════════════════

class Patient {
  final String name;
  final String healthId;
  final String dob;
  final int age;
  final String gender;
  final String blood;
  final String phoneMasked;
  final List<String> allergies;
  final List<String> chronic;
  final String emergencyName;
  final String emergencyPhone;

  const Patient({
    required this.name,
    required this.healthId,
    required this.dob,
    required this.age,
    required this.gender,
    required this.blood,
    required this.phoneMasked,
    required this.allergies,
    required this.chronic,
    required this.emergencyName,
    required this.emergencyPhone,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

const mockPatient = Patient(
  name: 'Ayesha Khan',
  healthId: 'PK-HC-9F2A-7T',
  dob: '14 Mar 1958',
  age: 58,
  gender: 'Female',
  blood: 'B+',
  phoneMasked: '+92 3••••••21',
  allergies: ['Penicillin', 'Sulfa drugs'],
  chronic: ['Hypertension', 'Type 2 Diabetes'],
  emergencyName: 'Bilal Khan',
  emergencyPhone: '+92 3••••••88',
);

/// Raw QR payload encoded on the health card.
const kHealthCardQr = 'PK-HC-9F2A-7T|Ayesha Khan|B+|1958-03-14';

// ═══════════════════════════════════════════════════════════════════════
//  Onboarding
// ═══════════════════════════════════════════════════════════════════════

class OnboardSlide {
  final String title;
  final String desc;
  final IconData icon;
  const OnboardSlide(this.title, this.desc, this.icon);
}

const mockOnboarding = [
  OnboardSlide(
      'A Digital Health Card for life',
      'One secure card carries your full medical history wherever you go.',
      Icons.badge_rounded),
  OnboardSlide(
      'Your history in a QR code',
      'Show your QR at any clinic. Doctors instantly see your records — securely.',
      Icons.qr_code_2_rounded),
  OnboardSlide(
      'Doctors update after each visit',
      'New diagnoses, medicines and reports appear on your phone the moment they’re added.',
      Icons.edit_document),
  OnboardSlide(
      'Secure, private access',
      'Only verified doctors can open your record, and only with your consent.',
      Icons.verified_user_rounded),
];

// ═══════════════════════════════════════════════════════════════════════
//  Visits / Medical history
// ═══════════════════════════════════════════════════════════════════════

class Med {
  final String name;
  final String strength;
  final String freq;
  final String dur;
  const Med(this.name, this.strength, this.freq, this.dur);
}

class Visit {
  final String id;
  final String dx; // diagnosis title
  final String doctor;
  final String specialty;
  final String hospital;
  final String dateLabel; // '18 Jun 2026'
  final String time;
  final String symptoms;
  final String diagnosis; // 'Essential hypertension (I10)'
  final String diagnosisNote;
  final List<Med> meds;
  final String followUp;
  final String advice;

  const Visit({
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
}

const _htnMeds = [
  Med('Amlodipine', '5 mg', 'Once daily', '30 days'),
  Med('Metformin', '500 mg', 'Twice daily', 'Ongoing'),
  Med('Aspirin', '75 mg', 'Once daily', '30 days'),
];

const mockVisits = [
  Visit(
    id: 'v1',
    dx: 'Hypertension review',
    doctor: 'Dr. Imran Yousuf',
    specialty: 'Cardiology',
    hospital: 'Shifa International Hospital',
    dateLabel: '18 Jun 2026',
    time: '09:30',
    symptoms:
        'Occasional headaches, mild dizziness in mornings. BP 148/94 on arrival.',
    diagnosis: 'Essential hypertension (I10)',
    diagnosisNote: 'Well-controlled on current regimen. Continue monitoring.',
    meds: _htnMeds,
    followUp: '24 Jun 2026',
    advice: 'Reduce salt intake, 30-min daily walk.',
  ),
  Visit(
    id: 'v2',
    dx: 'Diabetes follow-up',
    doctor: 'Dr. Sana Tariq',
    specialty: 'Endocrinology',
    hospital: 'Aga Khan University Hospital',
    dateLabel: '02 May 2026',
    time: '11:15',
    symptoms: 'Fasting sugar trending high last week. No acute complaints.',
    diagnosis: 'Type 2 diabetes mellitus (E11)',
    diagnosisNote: 'HbA1c improving. Maintain diet and metformin.',
    meds: [
      Med('Metformin', '500 mg', 'Twice daily', 'Ongoing'),
      Med('Glimepiride', '1 mg', 'Once daily', '30 days'),
    ],
    followUp: '02 Aug 2026',
    advice: 'Low-carb diet, monitor sugar twice daily.',
  ),
  Visit(
    id: 'v3',
    dx: 'Chest pain — cleared',
    doctor: 'Dr. Imran Yousuf',
    specialty: 'Cardiology',
    hospital: 'Shifa International Hospital',
    dateLabel: '21 Mar 2026',
    time: '16:40',
    symptoms: 'Transient chest tightness on exertion. ECG normal.',
    diagnosis: 'Non-cardiac chest pain (R07.9)',
    diagnosisNote: 'Cardiac causes ruled out. Likely musculoskeletal.',
    meds: [Med('Pantoprazole', '40 mg', 'Once daily', '14 days')],
    followUp: 'As needed',
    advice: 'Return if pain recurs at rest.',
  ),
  Visit(
    id: 'v4',
    dx: 'Seasonal influenza',
    doctor: 'Dr. Bilal Aziz',
    specialty: 'General Medicine',
    hospital: 'CMH Lahore',
    dateLabel: '09 Feb 2026',
    time: '10:05',
    symptoms: 'Fever, body aches and dry cough for 3 days.',
    diagnosis: 'Influenza, unspecified (J11)',
    diagnosisNote: 'Symptomatic management. Rest and hydration.',
    meds: [
      Med('Paracetamol', '500 mg', 'As needed', '5 days'),
      Med('Cetirizine', '10 mg', 'Once at night', '5 days'),
    ],
    followUp: 'If not improving in 5 days',
    advice: 'Plenty of fluids and rest.',
  ),
];

/// Dashboard "recent activity" preview (top 2 visits).
const mockRecentActivity = [
  (dx: 'Hypertension review', doctor: 'Dr. Imran Yousuf', specialty: 'Cardiology', date: '18 Jun'),
  (dx: 'Diabetes follow-up', doctor: 'Dr. Sana Tariq', specialty: 'Endocrinology', date: '02 May'),
];

// ═══════════════════════════════════════════════════════════════════════
//  Prescriptions
// ═══════════════════════════════════════════════════════════════════════

class Prescription {
  final String id;
  final String name;
  final String strength;
  final String freq;
  final String dur;
  final String by;
  final String date;
  final bool active;
  final String? warn;

  const Prescription({
    required this.id,
    required this.name,
    required this.strength,
    required this.freq,
    required this.dur,
    required this.by,
    required this.date,
    required this.active,
    this.warn,
  });
}

const mockPrescriptions = [
  Prescription(
    id: 'rx1',
    name: 'Amlodipine',
    strength: '5 mg',
    freq: 'Once daily',
    dur: '30 days',
    by: 'Dr. Imran Yousuf',
    date: '18 Jun',
    active: true,
  ),
  Prescription(
    id: 'rx2',
    name: 'Metformin',
    strength: '500 mg',
    freq: 'Twice daily',
    dur: 'Ongoing',
    by: 'Dr. Sana Tariq',
    date: '02 May',
    active: true,
  ),
  Prescription(
    id: 'rx3',
    name: 'Aspirin',
    strength: '75 mg',
    freq: 'Once daily',
    dur: '30 days',
    by: 'Dr. Imran Yousuf',
    date: '18 Jun',
    active: true,
    warn: 'Avoid with Penicillin-class drugs',
  ),
  Prescription(
    id: 'rx4',
    name: 'Pantoprazole',
    strength: '40 mg',
    freq: 'Once daily',
    dur: 'Completed',
    by: 'Dr. Imran Yousuf',
    date: '21 Mar',
    active: false,
  ),
];

// ═══════════════════════════════════════════════════════════════════════
//  Reports / Lab results
// ═══════════════════════════════════════════════════════════════════════

enum ReportStatus { ready, reviewed, abnormal }

class Report {
  final String id;
  final String name;
  final String lab;
  final String date;
  final ReportStatus status;

  const Report({
    required this.id,
    required this.name,
    required this.lab,
    required this.date,
    required this.status,
  });

  String get statusLabel => switch (status) {
        ReportStatus.ready => 'Ready',
        ReportStatus.reviewed => 'Reviewed',
        ReportStatus.abnormal => 'Abnormal',
      };
}

const mockReports = [
  Report(id: 'r1', name: 'Lipid Profile', lab: 'Shifa Lab', date: '18 Jun 2026', status: ReportStatus.ready),
  Report(id: 'r2', name: 'HbA1c', lab: 'Shifa Lab', date: '18 Jun 2026', status: ReportStatus.ready),
  Report(id: 'r3', name: 'Chest X-Ray', lab: 'Aga Khan', date: '02 May 2026', status: ReportStatus.reviewed),
  Report(id: 'r4', name: 'Fasting Blood Sugar', lab: 'Chughtai Lab', date: '02 May 2026', status: ReportStatus.abnormal),
];

// ═══════════════════════════════════════════════════════════════════════
//  Messages / Conversations
// ═══════════════════════════════════════════════════════════════════════

class ChatMessage {
  final String text;
  final bool fromMe;
  final String time;
  const ChatMessage(
      {required this.text, required this.fromMe, required this.time});
}

class Conversation {
  final String doctorId;
  final String initials;
  final String name;
  final String last;
  final String time;
  final int unread;
  final bool online;
  final List<ChatMessage> messages;

  const Conversation({
    required this.doctorId,
    required this.initials,
    required this.name,
    required this.last,
    required this.time,
    required this.unread,
    required this.online,
    required this.messages,
  });
}

const mockConversations = [
  Conversation(
    doctorId: 'imran',
    initials: 'IY',
    name: 'Dr. Imran Yousuf',
    last: 'Yes, same dose. I’ve added it to your…',
    time: '09:21',
    unread: 1,
    online: true,
    messages: [
      ChatMessage(
          text: 'Your BP readings look stable. Keep logging twice daily.',
          fromMe: false,
          time: '09:12'),
      ChatMessage(
          text: 'Thank you doctor. Should I continue Amlodipine?',
          fromMe: true,
          time: '09:20'),
      ChatMessage(
          text: 'Yes, same dose. I’ve added it to your prescriptions.',
          fromMe: false,
          time: '09:21'),
    ],
  ),
  Conversation(
    doctorId: 'sana',
    initials: 'ST',
    name: 'Dr. Sana Tariq',
    last: 'Your HbA1c looks much better.',
    time: 'Yesterday',
    unread: 0,
    online: false,
    messages: [
      ChatMessage(
          text: 'I uploaded my fasting sugar log for the week.',
          fromMe: true,
          time: '18:02'),
      ChatMessage(
          text: 'Your HbA1c looks much better. Well done!',
          fromMe: false,
          time: '18:30'),
    ],
  ),
  Conversation(
    doctorId: 'care',
    initials: 'SC',
    name: 'Sehat Care Team',
    last: 'Welcome to Sehat ID 👋',
    time: 'Mon',
    unread: 0,
    online: false,
    messages: [
      ChatMessage(
          text: 'Welcome to Sehat ID 👋 We’re here if you need anything.',
          fromMe: false,
          time: 'Mon'),
    ],
  ),
];

// ═══════════════════════════════════════════════════════════════════════
//  Notifications
// ═══════════════════════════════════════════════════════════════════════

enum NotifKind { safe, info, primary, warn, danger }

class AppNotification {
  final String title;
  final String sub;
  final String time;
  final NotifKind kind;
  final IconData icon;

  const AppNotification({
    required this.title,
    required this.sub,
    required this.time,
    required this.kind,
    required this.icon,
  });
}

const mockNotifications = [
  AppNotification(
      title: 'New prescription added',
      sub: 'Dr. Imran Yousuf prescribed Amlodipine 5mg',
      time: '2h ago',
      kind: NotifKind.safe,
      icon: Icons.medication_rounded),
  AppNotification(
      title: 'Lab report uploaded',
      sub: 'Lipid Profile results are ready to view',
      time: '5h ago',
      kind: NotifKind.info,
      icon: Icons.science_rounded),
  AppNotification(
      title: 'New message',
      sub: 'Dr. Imran Yousuf sent you a message',
      time: 'Yesterday',
      kind: NotifKind.primary,
      icon: Icons.chat_bubble_rounded),
  AppNotification(
      title: 'Appointment reminder',
      sub: 'Follow-up with Dr. Imran on 24 Jun',
      time: 'Yesterday',
      kind: NotifKind.warn,
      icon: Icons.event_rounded),
  AppNotification(
      title: 'New login detected',
      sub: 'Sign-in from Lahore · Android device',
      time: '2 days ago',
      kind: NotifKind.danger,
      icon: Icons.lock_rounded),
];

// ═══════════════════════════════════════════════════════════════════════
//  Dashboard summary stats
// ═══════════════════════════════════════════════════════════════════════

const kActiveMeds = 4;
const kAllergyCount = 2;
const kRecentVisits = 7;

const kAllergySuggestions = ['Penicillin', 'Sulfa', 'Aspirin', 'Latex', 'Pollen'];
const kBloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
