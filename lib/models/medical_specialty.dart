import 'package:flutter/material.dart';

/// Patient-facing clinical domains. These are deliberately broader than a
/// provider directory so patients do not need to know a subspecialty name.
@immutable
class MedicalSpecialty {
  final String id;
  final String name;
  final String bodySystem;
  final IconData icon;
  final List<String> aliases;

  const MedicalSpecialty({
    required this.id,
    required this.name,
    required this.bodySystem,
    required this.icon,
    this.aliases = const [],
  });

  String get displayName => '$name · $bodySystem';
}

class MedicalSpecialties {
  MedicalSpecialties._();

  static const general = MedicalSpecialty(
    id: 'general-medicine',
    name: 'General & Family Medicine',
    bodySystem: 'Whole-person care',
    icon: Icons.health_and_safety_rounded,
    aliases: [
      'general medicine',
      'family medicine',
      'internal medicine',
      'primary care',
      'geriatrics',
    ],
  );

  /// Head-to-toe, patient-friendly taxonomy used throughout the product.
  static const all = <MedicalSpecialty>[
    MedicalSpecialty(
      id: 'neurology',
      name: 'Neurology',
      bodySystem: 'Brain & nervous system',
      icon: Icons.psychology_alt_rounded,
      aliases: ['neurology', 'neurosurgery', 'brain', 'nervous system'],
    ),
    MedicalSpecialty(
      id: 'ophthalmology',
      name: 'Eye Care',
      bodySystem: 'Eyes & vision',
      icon: Icons.visibility_rounded,
      aliases: ['ophthalmology', 'optometry', 'eye', 'vision'],
    ),
    MedicalSpecialty(
      id: 'ent',
      name: 'ENT',
      bodySystem: 'Ear, nose & throat',
      icon: Icons.hearing_rounded,
      aliases: ['ent', 'otolaryngology', 'ear nose throat', 'audiology'],
    ),
    MedicalSpecialty(
      id: 'oral-health',
      name: 'Dental & Oral Health',
      bodySystem: 'Teeth, mouth & jaw',
      icon: Icons.sentiment_satisfied_alt_rounded,
      aliases: ['dentistry', 'dental', 'oral', 'maxillofacial', 'orthodontics'],
    ),
    MedicalSpecialty(
      id: 'dermatology',
      name: 'Dermatology',
      bodySystem: 'Skin, hair & nails',
      icon: Icons.healing_rounded,
      aliases: ['dermatology', 'skin', 'hair', 'nail'],
    ),
    MedicalSpecialty(
      id: 'cardiology',
      name: 'Cardiology',
      bodySystem: 'Heart & circulation',
      icon: Icons.favorite_rounded,
      aliases: ['cardiology', 'cardiac', 'heart', 'vascular', 'circulation'],
    ),
    MedicalSpecialty(
      id: 'pulmonology',
      name: 'Respiratory Care',
      bodySystem: 'Lungs & breathing',
      icon: Icons.air_rounded,
      aliases: [
        'pulmonology',
        'respiratory',
        'chest',
        'lung',
        'sleep medicine',
      ],
    ),
    MedicalSpecialty(
      id: 'gastroenterology',
      name: 'Gastroenterology',
      bodySystem: 'Stomach & digestive system',
      icon: Icons.restaurant_rounded,
      aliases: [
        'gastroenterology',
        'digestive',
        'stomach',
        'bowel',
        'colorectal',
      ],
    ),
    MedicalSpecialty(
      id: 'hepatology',
      name: 'Liver & Gallbladder',
      bodySystem: 'Liver, bile ducts & pancreas',
      icon: Icons.medical_information_rounded,
      aliases: ['hepatology', 'liver', 'gallbladder', 'biliary', 'pancreas'],
    ),
    MedicalSpecialty(
      id: 'nephrology',
      name: 'Kidney Care',
      bodySystem: 'Kidneys',
      icon: Icons.water_drop_rounded,
      aliases: ['nephrology', 'renal', 'kidney', 'dialysis'],
    ),
    MedicalSpecialty(
      id: 'urology',
      name: 'Urology',
      bodySystem: 'Urinary & male reproductive system',
      icon: Icons.wc_rounded,
      aliases: ['urology', 'urinary', 'prostate', 'andrology', 'mens health'],
    ),
    MedicalSpecialty(
      id: 'gynecology',
      name: 'Women’s Health',
      bodySystem: 'Gynecology & breast health',
      icon: Icons.female_rounded,
      aliases: [
        'gynecology',
        'gynaecology',
        'womens health',
        'breast',
        'reproductive',
      ],
    ),
    MedicalSpecialty(
      id: 'obstetrics',
      name: 'Pregnancy & Maternity',
      bodySystem: 'Obstetrics',
      icon: Icons.pregnant_woman_rounded,
      aliases: [
        'obstetrics',
        'pregnancy',
        'maternity',
        'prenatal',
        'antenatal',
      ],
    ),
    MedicalSpecialty(
      id: 'endocrinology',
      name: 'Endocrinology',
      bodySystem: 'Hormones & metabolism',
      icon: Icons.hub_rounded,
      aliases: ['endocrinology', 'hormone', 'diabetes', 'thyroid', 'metabolic'],
    ),
    MedicalSpecialty(
      id: 'orthopedics',
      name: 'Orthopedics',
      bodySystem: 'Bones, joints & spine',
      icon: Icons.accessibility_new_rounded,
      aliases: [
        'orthopedics',
        'orthopaedics',
        'bone',
        'joint',
        'spine',
        'sports medicine',
      ],
    ),
    MedicalSpecialty(
      id: 'rheumatology',
      name: 'Rheumatology',
      bodySystem: 'Joints & autoimmune conditions',
      icon: Icons.pan_tool_alt_rounded,
      aliases: ['rheumatology', 'arthritis', 'autoimmune', 'connective tissue'],
    ),
    MedicalSpecialty(
      id: 'hematology',
      name: 'Hematology',
      bodySystem: 'Blood disorders',
      icon: Icons.bloodtype_rounded,
      aliases: ['hematology', 'haematology', 'blood'],
    ),
    MedicalSpecialty(
      id: 'oncology',
      name: 'Cancer Care',
      bodySystem: 'Oncology',
      icon: Icons.local_hospital_rounded,
      aliases: ['oncology', 'cancer', 'tumor', 'tumour', 'radiotherapy'],
    ),
    MedicalSpecialty(
      id: 'allergy-immunology',
      name: 'Allergy & Immunology',
      bodySystem: 'Allergies & immune system',
      icon: Icons.shield_rounded,
      aliases: ['allergy', 'immunology', 'immune'],
    ),
    MedicalSpecialty(
      id: 'infectious-disease',
      name: 'Infectious Diseases',
      bodySystem: 'Infections & tropical medicine',
      icon: Icons.coronavirus_rounded,
      aliases: ['infectious disease', 'infection', 'tropical medicine'],
    ),
    MedicalSpecialty(
      id: 'mental-health',
      name: 'Mental Health',
      bodySystem: 'Psychiatry & psychology',
      icon: Icons.self_improvement_rounded,
      aliases: [
        'psychiatry',
        'psychology',
        'mental health',
        'behavioral',
        'behavioural',
        'counselling',
      ],
    ),
    MedicalSpecialty(
      id: 'pediatrics',
      name: 'Child Health',
      bodySystem: 'Pediatrics & newborn care',
      icon: Icons.child_care_rounded,
      aliases: ['pediatrics', 'paediatrics', 'child', 'neonatal', 'newborn'],
    ),
    general,
    MedicalSpecialty(
      id: 'surgery',
      name: 'Surgery & Procedures',
      bodySystem: 'Operations & procedural care',
      icon: Icons.medical_services_rounded,
      aliases: [
        'surgery',
        'surgical',
        'procedure',
        'anaesthesia',
        'anesthesia',
      ],
    ),
    MedicalSpecialty(
      id: 'pathology',
      name: 'Laboratory Medicine',
      bodySystem: 'Pathology & diagnostic tests',
      icon: Icons.science_rounded,
      aliases: [
        'pathology',
        'laboratory',
        'lab',
        'biochemistry',
        'microbiology',
      ],
    ),
    MedicalSpecialty(
      id: 'radiology',
      name: 'Imaging',
      bodySystem: 'X-ray, CT, MRI & ultrasound',
      icon: Icons.image_search_rounded,
      aliases: [
        'radiology',
        'imaging',
        'x-ray',
        'xray',
        'ct scan',
        'mri',
        'ultrasound',
        'mammography',
      ],
    ),
    MedicalSpecialty(
      id: 'emergency',
      name: 'Emergency & Critical Care',
      bodySystem: 'Urgent and intensive care',
      icon: Icons.emergency_rounded,
      aliases: [
        'emergency',
        'critical care',
        'intensive care',
        'icu',
        'accident',
      ],
    ),
    MedicalSpecialty(
      id: 'rehabilitation',
      name: 'Rehabilitation & Pain Care',
      bodySystem: 'Recovery, mobility & pain',
      icon: Icons.directions_walk_rounded,
      aliases: [
        'rehabilitation',
        'physiotherapy',
        'physical therapy',
        'occupational therapy',
        'pain medicine',
      ],
    ),
    MedicalSpecialty(
      id: 'genetics',
      name: 'Genetics & Rare Diseases',
      bodySystem: 'Inherited conditions',
      icon: Icons.biotech_rounded,
      aliases: ['genetics', 'genomic', 'rare disease', 'inherited'],
    ),
  ];

  static MedicalSpecialty byId(String id) =>
      all.firstWhere((item) => item.id == id, orElse: () => general);

  static MedicalSpecialty resolve(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty) return general;
    for (final specialty in all) {
      if (specialty.id == value || specialty.name.toLowerCase() == value) {
        return specialty;
      }
      if (specialty.aliases.any(
        (alias) => value.contains(alias) || alias.contains(value),
      )) {
        return specialty;
      }
    }
    return general;
  }
}
