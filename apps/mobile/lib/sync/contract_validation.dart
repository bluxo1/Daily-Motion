import '../domain/workout.dart';

class ContractViolation implements Exception {
  final String code;
  const ContractViolation([this.code = 'malformed_response']);
  @override
  String toString() => code;
}

/// Validate the supported OpenAPI JSON Schema subset. Unknown schema features fail
/// at generation time; unknown wire properties fail here on closed sync objects.
void validateSchema(Object? value, Json schema, Json definitions) {
  Never fail() => throw const ContractViolation();
  if (schema.containsKey(r'$ref')) {
    validateSchema(
      value,
      definitions[(schema[r'$ref'] as String).split('/').last] as Json,
      definitions,
    );
    return;
  }
  for (final keyword in ['anyOf', 'oneOf']) {
    if (schema[keyword] != null) {
      var matched = 0;
      for (final alternative in schema[keyword] as List) {
        try {
          validateSchema(value, alternative as Json, definitions);
          matched++;
        } on ContractViolation {
          /* Try the next declared alternative. */
        }
      }
      if (matched == 0 || (keyword == 'oneOf' && matched != 1)) fail();
    }
  }
  if (schema.containsKey('const') && value != schema['const']) fail();
  if (schema['enum'] != null && !(schema['enum'] as List).contains(value)) {
    fail();
  }
  switch (schema['type']) {
    case 'null':
      if (value != null) fail();
    case 'boolean':
      if (value is! bool) fail();
    case 'integer':
      if (value is! int ||
          value < 0 && schema['minimum'] == 0 ||
          value > 9223372036854775807) {
        fail();
      }
      if (schema['minimum'] != null && value < schema['minimum']) fail();
      if (schema['maximum'] != null && value > schema['maximum']) fail();
    case 'number':
      if (value is! num || !value.isFinite) fail();
    case 'string':
      if (value is! String) fail();
      if (schema['minLength'] != null &&
          value.runes.length < schema['minLength']) {
        fail();
      }
      if (schema['maxLength'] != null &&
          value.runes.length > schema['maxLength']) {
        fail();
      }
      if (schema['pattern'] != null &&
          !RegExp(schema['pattern'] as String).hasMatch(value)) {
        fail();
      }
      if (schema['format'] == 'uuid' &&
          !RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
          ).hasMatch(value)) {
        fail();
      }
      if (schema['format'] == 'date-time' && !isUtcInstant(value)) {
        throw const ContractViolation('invalid_timestamp');
      }
    case 'array':
      if (value is! List) fail();
      if (schema['minItems'] != null && value.length < schema['minItems']) {
        fail();
      }
      if (schema['maxItems'] != null && value.length > schema['maxItems']) {
        fail();
      }
      for (final item in value) {
        validateSchema(item, schema['items'] as Json, definitions);
      }
    case 'object':
      if (value is! Json) fail();
      final properties = schema['properties'] as Json? ?? {};
      for (final key in schema['required'] as List? ?? []) {
        if (!value.containsKey(key)) fail();
      }
      for (final entry in value.entries) {
        if (properties.containsKey(entry.key)) {
          validateSchema(
            entry.value,
            properties[entry.key] as Json,
            definitions,
          );
        } else if (schema['additionalProperties'] == false) {
          fail();
        } else if (schema['additionalProperties'] is Json) {
          validateSchema(
            entry.value,
            schema['additionalProperties'] as Json,
            definitions,
          );
        }
      }
      final commands =
          (properties['payload'] as Json?)?['x-command-schemas'] as Json?;
      if (commands != null) {
        if (!isUtcInstant(value['occurred_at']) ||
            !isUtcInstant(value['recorded_at'])) {
          throw const ContractViolation('invalid_timestamp');
        }
        final payloadSchema = commands[value['command']];
        if (payloadSchema == null) fail();
        validateSchema(
          value['payload'],
          definitions[payloadSchema] as Json,
          definitions,
        );
      }
  }
}

Object? contractDefaults(Object? value, Json schema, Json definitions) {
  if (schema[r'$ref'] != null) {
    return contractDefaults(
      value,
      definitions[(schema[r'$ref'] as String).split('/').last] as Json,
      definitions,
    );
  }
  for (final keyword in ['anyOf', 'oneOf']) {
    if (schema[keyword] != null) {
      for (final raw in schema[keyword] as List) {
        final alternative = raw as Json;
        try {
          validateSchema(value, alternative, definitions);
          return contractDefaults(value, alternative, definitions);
        } on ContractViolation {
          /* Match the declared shape first. */
        }
      }
    }
  }
  if (value is List && schema['items'] is Json) {
    return value
        .map((v) => contractDefaults(v, schema['items'] as Json, definitions))
        .toList();
  }
  if (value is Json && schema['properties'] is Json) {
    final result = copyJson(value);
    for (final entry in (schema['properties'] as Json).entries) {
      final field = entry.value as Json;
      if (!result.containsKey(entry.key) && field.containsKey('default')) {
        result[entry.key] = field['default'];
      }
      if (result.containsKey(entry.key)) {
        result[entry.key] = contractDefaults(
          result[entry.key],
          field,
          definitions,
        );
      }
    }
    return result;
  }
  return value;
}

Json domainTransportOperation(Json operation, Json definitions) {
  final result = copyJson(operation);
  final commandSchema =
      ((definitions['Operation']
              as Json)['properties']['payload']['x-command-schemas']
          as Json)[operation['command']];
  if (commandSchema == null) throw const ContractViolation();
  result['payload'] = contractDefaults(
    operation['payload'],
    definitions[commandSchema] as Json,
    definitions,
  );
  return result;
}

Json? applyRemoteOperation(
  Json? previous,
  Json operation,
  Json definitions, {
  required int revision,
}) {
  try {
    return applyOperation(
      previous,
      domainTransportOperation(operation, definitions),
      revision: revision,
    );
  } on WorkoutValidation {
    throw const ContractViolation('invalid_remote_state');
  }
}
