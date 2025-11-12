import 'package:freezed_annotation/freezed_annotation.dart';

part 'counter.freezed.dart';
part 'counter.g.dart';

@freezed
class Counter with _$Counter {
  const factory Counter({
    int? id,
    required String name,
    String? description,
    required DateTime eventDate,
    String? category,
    String? recurrence,
    // Campos específicos de corridas
    required String status,
    required double distanceKm,
    double? price,
    String? registrationUrl,
    String? finishTime,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Counter;

  factory Counter.fromJson(Map<String, dynamic> json) => _$CounterFromJson(json);
}