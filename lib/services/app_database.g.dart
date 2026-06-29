// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ScanHistoryTableTable extends ScanHistoryTable
    with TableInfo<$ScanHistoryTableTable, ScanHistoryTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanHistoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputTypeMeta = const VerificationMeta(
    'inputType',
  );
  @override
  late final GeneratedColumn<String> inputType = GeneratedColumn<String>(
    'input_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _barcodeValueMeta = const VerificationMeta(
    'barcodeValue',
  );
  @override
  late final GeneratedColumn<String> barcodeValue = GeneratedColumn<String>(
    'barcode_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barcodeFormatMeta = const VerificationMeta(
    'barcodeFormat',
  );
  @override
  late final GeneratedColumn<String> barcodeFormat = GeneratedColumn<String>(
    'barcode_format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ocrTextMeta = const VerificationMeta(
    'ocrText',
  );
  @override
  late final GeneratedColumn<String> ocrText = GeneratedColumn<String>(
    'ocr_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kvPairsJsonMeta = const VerificationMeta(
    'kvPairsJson',
  );
  @override
  late final GeneratedColumn<String> kvPairsJson = GeneratedColumn<String>(
    'kv_pairs_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productNameMeta = const VerificationMeta(
    'productName',
  );
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
    'product_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productBrandMeta = const VerificationMeta(
    'productBrand',
  );
  @override
  late final GeneratedColumn<String> productBrand = GeneratedColumn<String>(
    'product_brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    inputType,
    barcodeValue,
    barcodeFormat,
    ocrText,
    kvPairsJson,
    productName,
    productBrand,
    imagePath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_history_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanHistoryTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('input_type')) {
      context.handle(
        _inputTypeMeta,
        inputType.isAcceptableOrUnknown(data['input_type']!, _inputTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_inputTypeMeta);
    }
    if (data.containsKey('barcode_value')) {
      context.handle(
        _barcodeValueMeta,
        barcodeValue.isAcceptableOrUnknown(
          data['barcode_value']!,
          _barcodeValueMeta,
        ),
      );
    }
    if (data.containsKey('barcode_format')) {
      context.handle(
        _barcodeFormatMeta,
        barcodeFormat.isAcceptableOrUnknown(
          data['barcode_format']!,
          _barcodeFormatMeta,
        ),
      );
    }
    if (data.containsKey('ocr_text')) {
      context.handle(
        _ocrTextMeta,
        ocrText.isAcceptableOrUnknown(data['ocr_text']!, _ocrTextMeta),
      );
    }
    if (data.containsKey('kv_pairs_json')) {
      context.handle(
        _kvPairsJsonMeta,
        kvPairsJson.isAcceptableOrUnknown(
          data['kv_pairs_json']!,
          _kvPairsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_kvPairsJsonMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
        _productNameMeta,
        productName.isAcceptableOrUnknown(
          data['product_name']!,
          _productNameMeta,
        ),
      );
    }
    if (data.containsKey('product_brand')) {
      context.handle(
        _productBrandMeta,
        productBrand.isAcceptableOrUnknown(
          data['product_brand']!,
          _productBrandMeta,
        ),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanHistoryTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanHistoryTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      inputType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_type'],
      )!,
      barcodeValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode_value'],
      ),
      barcodeFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode_format'],
      ),
      ocrText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_text'],
      ),
      kvPairsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kv_pairs_json'],
      )!,
      productName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name'],
      ),
      productBrand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_brand'],
      ),
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
    );
  }

  @override
  $ScanHistoryTableTable createAlias(String alias) {
    return $ScanHistoryTableTable(attachedDatabase, alias);
  }
}

class ScanHistoryTableData extends DataClass
    implements Insertable<ScanHistoryTableData> {
  final int id;
  final DateTime createdAt;
  final String inputType;
  final String? barcodeValue;
  final String? barcodeFormat;
  final String? ocrText;
  final String kvPairsJson;
  final String? productName;
  final String? productBrand;
  final String? imagePath;
  const ScanHistoryTableData({
    required this.id,
    required this.createdAt,
    required this.inputType,
    this.barcodeValue,
    this.barcodeFormat,
    this.ocrText,
    required this.kvPairsJson,
    this.productName,
    this.productBrand,
    this.imagePath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['input_type'] = Variable<String>(inputType);
    if (!nullToAbsent || barcodeValue != null) {
      map['barcode_value'] = Variable<String>(barcodeValue);
    }
    if (!nullToAbsent || barcodeFormat != null) {
      map['barcode_format'] = Variable<String>(barcodeFormat);
    }
    if (!nullToAbsent || ocrText != null) {
      map['ocr_text'] = Variable<String>(ocrText);
    }
    map['kv_pairs_json'] = Variable<String>(kvPairsJson);
    if (!nullToAbsent || productName != null) {
      map['product_name'] = Variable<String>(productName);
    }
    if (!nullToAbsent || productBrand != null) {
      map['product_brand'] = Variable<String>(productBrand);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    return map;
  }

  ScanHistoryTableCompanion toCompanion(bool nullToAbsent) {
    return ScanHistoryTableCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      inputType: Value(inputType),
      barcodeValue: barcodeValue == null && nullToAbsent
          ? const Value.absent()
          : Value(barcodeValue),
      barcodeFormat: barcodeFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(barcodeFormat),
      ocrText: ocrText == null && nullToAbsent
          ? const Value.absent()
          : Value(ocrText),
      kvPairsJson: Value(kvPairsJson),
      productName: productName == null && nullToAbsent
          ? const Value.absent()
          : Value(productName),
      productBrand: productBrand == null && nullToAbsent
          ? const Value.absent()
          : Value(productBrand),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
    );
  }

  factory ScanHistoryTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanHistoryTableData(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      inputType: serializer.fromJson<String>(json['inputType']),
      barcodeValue: serializer.fromJson<String?>(json['barcodeValue']),
      barcodeFormat: serializer.fromJson<String?>(json['barcodeFormat']),
      ocrText: serializer.fromJson<String?>(json['ocrText']),
      kvPairsJson: serializer.fromJson<String>(json['kvPairsJson']),
      productName: serializer.fromJson<String?>(json['productName']),
      productBrand: serializer.fromJson<String?>(json['productBrand']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'inputType': serializer.toJson<String>(inputType),
      'barcodeValue': serializer.toJson<String?>(barcodeValue),
      'barcodeFormat': serializer.toJson<String?>(barcodeFormat),
      'ocrText': serializer.toJson<String?>(ocrText),
      'kvPairsJson': serializer.toJson<String>(kvPairsJson),
      'productName': serializer.toJson<String?>(productName),
      'productBrand': serializer.toJson<String?>(productBrand),
      'imagePath': serializer.toJson<String?>(imagePath),
    };
  }

  ScanHistoryTableData copyWith({
    int? id,
    DateTime? createdAt,
    String? inputType,
    Value<String?> barcodeValue = const Value.absent(),
    Value<String?> barcodeFormat = const Value.absent(),
    Value<String?> ocrText = const Value.absent(),
    String? kvPairsJson,
    Value<String?> productName = const Value.absent(),
    Value<String?> productBrand = const Value.absent(),
    Value<String?> imagePath = const Value.absent(),
  }) => ScanHistoryTableData(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    inputType: inputType ?? this.inputType,
    barcodeValue: barcodeValue.present ? barcodeValue.value : this.barcodeValue,
    barcodeFormat: barcodeFormat.present
        ? barcodeFormat.value
        : this.barcodeFormat,
    ocrText: ocrText.present ? ocrText.value : this.ocrText,
    kvPairsJson: kvPairsJson ?? this.kvPairsJson,
    productName: productName.present ? productName.value : this.productName,
    productBrand: productBrand.present ? productBrand.value : this.productBrand,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
  );
  ScanHistoryTableData copyWithCompanion(ScanHistoryTableCompanion data) {
    return ScanHistoryTableData(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      inputType: data.inputType.present ? data.inputType.value : this.inputType,
      barcodeValue: data.barcodeValue.present
          ? data.barcodeValue.value
          : this.barcodeValue,
      barcodeFormat: data.barcodeFormat.present
          ? data.barcodeFormat.value
          : this.barcodeFormat,
      ocrText: data.ocrText.present ? data.ocrText.value : this.ocrText,
      kvPairsJson: data.kvPairsJson.present
          ? data.kvPairsJson.value
          : this.kvPairsJson,
      productName: data.productName.present
          ? data.productName.value
          : this.productName,
      productBrand: data.productBrand.present
          ? data.productBrand.value
          : this.productBrand,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanHistoryTableData(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('inputType: $inputType, ')
          ..write('barcodeValue: $barcodeValue, ')
          ..write('barcodeFormat: $barcodeFormat, ')
          ..write('ocrText: $ocrText, ')
          ..write('kvPairsJson: $kvPairsJson, ')
          ..write('productName: $productName, ')
          ..write('productBrand: $productBrand, ')
          ..write('imagePath: $imagePath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    inputType,
    barcodeValue,
    barcodeFormat,
    ocrText,
    kvPairsJson,
    productName,
    productBrand,
    imagePath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanHistoryTableData &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.inputType == this.inputType &&
          other.barcodeValue == this.barcodeValue &&
          other.barcodeFormat == this.barcodeFormat &&
          other.ocrText == this.ocrText &&
          other.kvPairsJson == this.kvPairsJson &&
          other.productName == this.productName &&
          other.productBrand == this.productBrand &&
          other.imagePath == this.imagePath);
}

class ScanHistoryTableCompanion extends UpdateCompanion<ScanHistoryTableData> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<String> inputType;
  final Value<String?> barcodeValue;
  final Value<String?> barcodeFormat;
  final Value<String?> ocrText;
  final Value<String> kvPairsJson;
  final Value<String?> productName;
  final Value<String?> productBrand;
  final Value<String?> imagePath;
  const ScanHistoryTableCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.inputType = const Value.absent(),
    this.barcodeValue = const Value.absent(),
    this.barcodeFormat = const Value.absent(),
    this.ocrText = const Value.absent(),
    this.kvPairsJson = const Value.absent(),
    this.productName = const Value.absent(),
    this.productBrand = const Value.absent(),
    this.imagePath = const Value.absent(),
  });
  ScanHistoryTableCompanion.insert({
    this.id = const Value.absent(),
    required DateTime createdAt,
    required String inputType,
    this.barcodeValue = const Value.absent(),
    this.barcodeFormat = const Value.absent(),
    this.ocrText = const Value.absent(),
    required String kvPairsJson,
    this.productName = const Value.absent(),
    this.productBrand = const Value.absent(),
    this.imagePath = const Value.absent(),
  }) : createdAt = Value(createdAt),
       inputType = Value(inputType),
       kvPairsJson = Value(kvPairsJson);
  static Insertable<ScanHistoryTableData> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<String>? inputType,
    Expression<String>? barcodeValue,
    Expression<String>? barcodeFormat,
    Expression<String>? ocrText,
    Expression<String>? kvPairsJson,
    Expression<String>? productName,
    Expression<String>? productBrand,
    Expression<String>? imagePath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (inputType != null) 'input_type': inputType,
      if (barcodeValue != null) 'barcode_value': barcodeValue,
      if (barcodeFormat != null) 'barcode_format': barcodeFormat,
      if (ocrText != null) 'ocr_text': ocrText,
      if (kvPairsJson != null) 'kv_pairs_json': kvPairsJson,
      if (productName != null) 'product_name': productName,
      if (productBrand != null) 'product_brand': productBrand,
      if (imagePath != null) 'image_path': imagePath,
    });
  }

  ScanHistoryTableCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<String>? inputType,
    Value<String?>? barcodeValue,
    Value<String?>? barcodeFormat,
    Value<String?>? ocrText,
    Value<String>? kvPairsJson,
    Value<String?>? productName,
    Value<String?>? productBrand,
    Value<String?>? imagePath,
  }) {
    return ScanHistoryTableCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      inputType: inputType ?? this.inputType,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      barcodeFormat: barcodeFormat ?? this.barcodeFormat,
      ocrText: ocrText ?? this.ocrText,
      kvPairsJson: kvPairsJson ?? this.kvPairsJson,
      productName: productName ?? this.productName,
      productBrand: productBrand ?? this.productBrand,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (inputType.present) {
      map['input_type'] = Variable<String>(inputType.value);
    }
    if (barcodeValue.present) {
      map['barcode_value'] = Variable<String>(barcodeValue.value);
    }
    if (barcodeFormat.present) {
      map['barcode_format'] = Variable<String>(barcodeFormat.value);
    }
    if (ocrText.present) {
      map['ocr_text'] = Variable<String>(ocrText.value);
    }
    if (kvPairsJson.present) {
      map['kv_pairs_json'] = Variable<String>(kvPairsJson.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (productBrand.present) {
      map['product_brand'] = Variable<String>(productBrand.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanHistoryTableCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('inputType: $inputType, ')
          ..write('barcodeValue: $barcodeValue, ')
          ..write('barcodeFormat: $barcodeFormat, ')
          ..write('ocrText: $ocrText, ')
          ..write('kvPairsJson: $kvPairsJson, ')
          ..write('productName: $productName, ')
          ..write('productBrand: $productBrand, ')
          ..write('imagePath: $imagePath')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ScanHistoryTableTable scanHistoryTable = $ScanHistoryTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [scanHistoryTable];
}

typedef $$ScanHistoryTableTableCreateCompanionBuilder =
    ScanHistoryTableCompanion Function({
      Value<int> id,
      required DateTime createdAt,
      required String inputType,
      Value<String?> barcodeValue,
      Value<String?> barcodeFormat,
      Value<String?> ocrText,
      required String kvPairsJson,
      Value<String?> productName,
      Value<String?> productBrand,
      Value<String?> imagePath,
    });
typedef $$ScanHistoryTableTableUpdateCompanionBuilder =
    ScanHistoryTableCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<String> inputType,
      Value<String?> barcodeValue,
      Value<String?> barcodeFormat,
      Value<String?> ocrText,
      Value<String> kvPairsJson,
      Value<String?> productName,
      Value<String?> productBrand,
      Value<String?> imagePath,
    });

class $$ScanHistoryTableTableFilterComposer
    extends Composer<_$AppDatabase, $ScanHistoryTableTable> {
  $$ScanHistoryTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputType => $composableBuilder(
    column: $table.inputType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcodeValue => $composableBuilder(
    column: $table.barcodeValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcodeFormat => $composableBuilder(
    column: $table.barcodeFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kvPairsJson => $composableBuilder(
    column: $table.kvPairsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productBrand => $composableBuilder(
    column: $table.productBrand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanHistoryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanHistoryTableTable> {
  $$ScanHistoryTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputType => $composableBuilder(
    column: $table.inputType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcodeValue => $composableBuilder(
    column: $table.barcodeValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcodeFormat => $composableBuilder(
    column: $table.barcodeFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kvPairsJson => $composableBuilder(
    column: $table.kvPairsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productBrand => $composableBuilder(
    column: $table.productBrand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanHistoryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanHistoryTableTable> {
  $$ScanHistoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get inputType =>
      $composableBuilder(column: $table.inputType, builder: (column) => column);

  GeneratedColumn<String> get barcodeValue => $composableBuilder(
    column: $table.barcodeValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get barcodeFormat => $composableBuilder(
    column: $table.barcodeFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ocrText =>
      $composableBuilder(column: $table.ocrText, builder: (column) => column);

  GeneratedColumn<String> get kvPairsJson => $composableBuilder(
    column: $table.kvPairsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productBrand => $composableBuilder(
    column: $table.productBrand,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);
}

class $$ScanHistoryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanHistoryTableTable,
          ScanHistoryTableData,
          $$ScanHistoryTableTableFilterComposer,
          $$ScanHistoryTableTableOrderingComposer,
          $$ScanHistoryTableTableAnnotationComposer,
          $$ScanHistoryTableTableCreateCompanionBuilder,
          $$ScanHistoryTableTableUpdateCompanionBuilder,
          (
            ScanHistoryTableData,
            BaseReferences<
              _$AppDatabase,
              $ScanHistoryTableTable,
              ScanHistoryTableData
            >,
          ),
          ScanHistoryTableData,
          PrefetchHooks Function()
        > {
  $$ScanHistoryTableTableTableManager(
    _$AppDatabase db,
    $ScanHistoryTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanHistoryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanHistoryTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanHistoryTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> inputType = const Value.absent(),
                Value<String?> barcodeValue = const Value.absent(),
                Value<String?> barcodeFormat = const Value.absent(),
                Value<String?> ocrText = const Value.absent(),
                Value<String> kvPairsJson = const Value.absent(),
                Value<String?> productName = const Value.absent(),
                Value<String?> productBrand = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
              }) => ScanHistoryTableCompanion(
                id: id,
                createdAt: createdAt,
                inputType: inputType,
                barcodeValue: barcodeValue,
                barcodeFormat: barcodeFormat,
                ocrText: ocrText,
                kvPairsJson: kvPairsJson,
                productName: productName,
                productBrand: productBrand,
                imagePath: imagePath,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime createdAt,
                required String inputType,
                Value<String?> barcodeValue = const Value.absent(),
                Value<String?> barcodeFormat = const Value.absent(),
                Value<String?> ocrText = const Value.absent(),
                required String kvPairsJson,
                Value<String?> productName = const Value.absent(),
                Value<String?> productBrand = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
              }) => ScanHistoryTableCompanion.insert(
                id: id,
                createdAt: createdAt,
                inputType: inputType,
                barcodeValue: barcodeValue,
                barcodeFormat: barcodeFormat,
                ocrText: ocrText,
                kvPairsJson: kvPairsJson,
                productName: productName,
                productBrand: productBrand,
                imagePath: imagePath,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanHistoryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanHistoryTableTable,
      ScanHistoryTableData,
      $$ScanHistoryTableTableFilterComposer,
      $$ScanHistoryTableTableOrderingComposer,
      $$ScanHistoryTableTableAnnotationComposer,
      $$ScanHistoryTableTableCreateCompanionBuilder,
      $$ScanHistoryTableTableUpdateCompanionBuilder,
      (
        ScanHistoryTableData,
        BaseReferences<
          _$AppDatabase,
          $ScanHistoryTableTable,
          ScanHistoryTableData
        >,
      ),
      ScanHistoryTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ScanHistoryTableTableTableManager get scanHistoryTable =>
      $$ScanHistoryTableTableTableManager(_db, _db.scanHistoryTable);
}
