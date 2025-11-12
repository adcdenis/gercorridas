// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'counter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Counter _$CounterFromJson(Map<String, dynamic> json) {
  return _Counter.fromJson(json);
}

/// @nodoc
mixin _$Counter {
  int? get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  DateTime get eventDate => throw _privateConstructorUsedError;
  String? get category => throw _privateConstructorUsedError;
  String? get recurrence =>
      throw _privateConstructorUsedError; // Campos específicos de corridas
  String get status => throw _privateConstructorUsedError;
  double get distanceKm => throw _privateConstructorUsedError;
  double? get price => throw _privateConstructorUsedError;
  String? get registrationUrl => throw _privateConstructorUsedError;
  String? get finishTime => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Counter to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Counter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CounterCopyWith<Counter> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CounterCopyWith<$Res> {
  factory $CounterCopyWith(Counter value, $Res Function(Counter) then) =
      _$CounterCopyWithImpl<$Res, Counter>;
  @useResult
  $Res call({
    int? id,
    String name,
    String? description,
    DateTime eventDate,
    String? category,
    String? recurrence,
    String status,
    double distanceKm,
    double? price,
    String? registrationUrl,
    String? finishTime,
    DateTime createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$CounterCopyWithImpl<$Res, $Val extends Counter>
    implements $CounterCopyWith<$Res> {
  _$CounterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Counter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? description = freezed,
    Object? eventDate = null,
    Object? category = freezed,
    Object? recurrence = freezed,
    Object? status = null,
    Object? distanceKm = null,
    Object? price = freezed,
    Object? registrationUrl = freezed,
    Object? finishTime = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int?,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            eventDate: null == eventDate
                ? _value.eventDate
                : eventDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            category: freezed == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String?,
            recurrence: freezed == recurrence
                ? _value.recurrence
                : recurrence // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            distanceKm: null == distanceKm
                ? _value.distanceKm
                : distanceKm // ignore: cast_nullable_to_non_nullable
                      as double,
            price: freezed == price
                ? _value.price
                : price // ignore: cast_nullable_to_non_nullable
                      as double?,
            registrationUrl: freezed == registrationUrl
                ? _value.registrationUrl
                : registrationUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            finishTime: freezed == finishTime
                ? _value.finishTime
                : finishTime // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CounterImplCopyWith<$Res> implements $CounterCopyWith<$Res> {
  factory _$$CounterImplCopyWith(
    _$CounterImpl value,
    $Res Function(_$CounterImpl) then,
  ) = __$$CounterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    String name,
    String? description,
    DateTime eventDate,
    String? category,
    String? recurrence,
    String status,
    double distanceKm,
    double? price,
    String? registrationUrl,
    String? finishTime,
    DateTime createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$CounterImplCopyWithImpl<$Res>
    extends _$CounterCopyWithImpl<$Res, _$CounterImpl>
    implements _$$CounterImplCopyWith<$Res> {
  __$$CounterImplCopyWithImpl(
    _$CounterImpl _value,
    $Res Function(_$CounterImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Counter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? description = freezed,
    Object? eventDate = null,
    Object? category = freezed,
    Object? recurrence = freezed,
    Object? status = null,
    Object? distanceKm = null,
    Object? price = freezed,
    Object? registrationUrl = freezed,
    Object? finishTime = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$CounterImpl(
        id: freezed == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int?,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        eventDate: null == eventDate
            ? _value.eventDate
            : eventDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        category: freezed == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String?,
        recurrence: freezed == recurrence
            ? _value.recurrence
            : recurrence // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        distanceKm: null == distanceKm
            ? _value.distanceKm
            : distanceKm // ignore: cast_nullable_to_non_nullable
                  as double,
        price: freezed == price
            ? _value.price
            : price // ignore: cast_nullable_to_non_nullable
                  as double?,
        registrationUrl: freezed == registrationUrl
            ? _value.registrationUrl
            : registrationUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        finishTime: freezed == finishTime
            ? _value.finishTime
            : finishTime // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CounterImpl implements _Counter {
  const _$CounterImpl({
    this.id,
    required this.name,
    this.description,
    required this.eventDate,
    this.category,
    this.recurrence,
    required this.status,
    required this.distanceKm,
    this.price,
    this.registrationUrl,
    this.finishTime,
    required this.createdAt,
    this.updatedAt,
  });

  factory _$CounterImpl.fromJson(Map<String, dynamic> json) =>
      _$$CounterImplFromJson(json);

  @override
  final int? id;
  @override
  final String name;
  @override
  final String? description;
  @override
  final DateTime eventDate;
  @override
  final String? category;
  @override
  final String? recurrence;
  // Campos específicos de corridas
  @override
  final String status;
  @override
  final double distanceKm;
  @override
  final double? price;
  @override
  final String? registrationUrl;
  @override
  final String? finishTime;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'Counter(id: $id, name: $name, description: $description, eventDate: $eventDate, category: $category, recurrence: $recurrence, status: $status, distanceKm: $distanceKm, price: $price, registrationUrl: $registrationUrl, finishTime: $finishTime, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CounterImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.eventDate, eventDate) ||
                other.eventDate == eventDate) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.recurrence, recurrence) ||
                other.recurrence == recurrence) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.distanceKm, distanceKm) ||
                other.distanceKm == distanceKm) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.registrationUrl, registrationUrl) ||
                other.registrationUrl == registrationUrl) &&
            (identical(other.finishTime, finishTime) ||
                other.finishTime == finishTime) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    description,
    eventDate,
    category,
    recurrence,
    status,
    distanceKm,
    price,
    registrationUrl,
    finishTime,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Counter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CounterImplCopyWith<_$CounterImpl> get copyWith =>
      __$$CounterImplCopyWithImpl<_$CounterImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CounterImplToJson(this);
  }
}

abstract class _Counter implements Counter {
  const factory _Counter({
    final int? id,
    required final String name,
    final String? description,
    required final DateTime eventDate,
    final String? category,
    final String? recurrence,
    required final String status,
    required final double distanceKm,
    final double? price,
    final String? registrationUrl,
    final String? finishTime,
    required final DateTime createdAt,
    final DateTime? updatedAt,
  }) = _$CounterImpl;

  factory _Counter.fromJson(Map<String, dynamic> json) = _$CounterImpl.fromJson;

  @override
  int? get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  DateTime get eventDate;
  @override
  String? get category;
  @override
  String? get recurrence; // Campos específicos de corridas
  @override
  String get status;
  @override
  double get distanceKm;
  @override
  double? get price;
  @override
  String? get registrationUrl;
  @override
  String? get finishTime;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of Counter
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CounterImplCopyWith<_$CounterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
