/// A HayaatID card (virtual or physical) for any role.
class CardModel {
  final String id;
  final String cardNumber;
  final String role;
  final String? nameEn;
  final String? nameUr;
  final String? dateOfBirth;
  final String? bloodGroup;
  final String? city;
  final String? photoUrl;
  final String status; // virtual | physical_requested | delivered
  final String? deliveryAddress;
  final num? deliveryFee;

  CardModel({
    required this.id,
    required this.cardNumber,
    required this.role,
    this.nameEn,
    this.nameUr,
    this.dateOfBirth,
    this.bloodGroup,
    this.city,
    this.photoUrl,
    this.status = 'virtual',
    this.deliveryAddress,
    this.deliveryFee,
  });

  bool get physicalRequested => status == 'physical_requested' || status == 'delivered';

  factory CardModel.fromJson(Map<String, dynamic> j) => CardModel(
        id: j['id'].toString(),
        cardNumber: (j['card_number'] ?? '').toString(),
        role: (j['role'] ?? 'patient').toString(),
        nameEn: j['name_en'] as String?,
        nameUr: j['name_ur'] as String?,
        dateOfBirth: j['date_of_birth'] as String?,
        bloodGroup: j['blood_group'] as String?,
        city: j['city'] as String?,
        photoUrl: j['photo_url'] as String?,
        status: (j['status'] ?? 'virtual').toString(),
        deliveryAddress: j['delivery_address'] as String?,
        deliveryFee: j['delivery_fee_pkr'] as num?,
      );
}
