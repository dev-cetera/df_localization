// //.title
// // ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
// //
// // Dart/Flutter (DF) Packages by dev-cetera.com & contributors. The use of this
// // source code is governed by an MIT-style license described in the LICENSE
// // file located in this project's root directory.
// //
// // See: https://opensource.org/license/mit
// //
// // ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
// //.title~

// import 'package:http/http.dart' as http;

// import '/_common.dart';

// final class FirestoreRESTServiceBroker extends DatabaseServiceInterface {
//   final String projectId;
//   final String accessToken;
//   final http.Client _httpClient = http.Client();

//   FirestoreRESTServiceBroker({
//     required this.projectId,
//     required this.accessToken,
//   });

//   // Helper method for constructing the base URL for Firestore REST API
//   String _getBaseURL() =>
//       'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

//   @pragma('vm:prefer-inline')
//   Map<String, String> get _authHeaders => {
//         'Authorization': 'Bearer $accessToken',
//         'Content-Type': 'application/json',
//       };

//   // TODO: We need to make this generic and move to DatabaseServiceInterface.

//   Future<List<TModel>> queryCollection<TModel extends Model>({
//     required DataRefModel collectionRef,
//     required TModel Function(Map<String, dynamic> data) fromJson,
//     List<Filter>? filters,
//     String? orderByField,
//     OrderDirection orderDirection = OrderDirection.ASCENDING,
//     int? limit,
//   }) async {
//     // Build the query using the filters
//     final structuredQuery = _buildStructuredQuery(
//       collectionId: collectionRef.collectionId,
//       filters: filters?.map((filter) => filter.toMap()).toList(), // Convert Filters to maps
//       orderByField: orderByField,
//       orderDirection: orderDirection,
//       limit: limit,
//     );

//     // Execute the query (implementation details omitted for brevity)
//     final response = await _executeQuery(structuredQuery, collectionRef.parentPath);
//     return response.map((data) {
//       final fields = data['fields'] as Map<String, dynamic>;
//       return fromJson(convertToLocalJson(fields));
//     }).toList();
//   }

//   Future<List<Map<String, dynamic>>> _executeQuery(
//     Map<String, dynamic> structuredQuery,
//     String parentPath,
//   ) async {
//     final url = Uri.parse('${[_getBaseURL(), parentPath].join('/')}:runQuery');

//     final body = jsonEncode({'structuredQuery': structuredQuery});

//     final response = await _httpClient.post(
//       url,
//       headers: {
//         ..._authHeaders,
//         'Content-Type': 'application/json',
//       },
//       body: body,
//     );

//     if (response.statusCode == 200) {
//       final jsonResponse = jsonDecode(response.body) as List<dynamic>;
//       return jsonResponse
//           .where((item) => item['document'] != null) // Filter out non-document entries
//           .map((item) => item['document'] as Map<String, dynamic>)
//           .toList();
//     } else {
//       throw Exception('Failed to query collection: ${response.statusCode} - ${response.body}');
//     }
//   }

//   @override
//   Stream<TModel> streamModel<TModel extends ReferencedModel>(
//     DataRef ref,
//     TModel Function(Map<String, dynamic> data) fromJson,
//   ) {
//     // Note: Streaming isn't directly supported by REST API, so we simulate with periodic polling
//     return Stream<Option<TModel>>.periodic(const Duration(seconds: 5))
//         .asyncMap((_) => _readModel(ref, fromJson).unwrap());
//   }

//   @override
//   Stream<Iterable<TModel>> streamModelCollection<TModel extends ReferencedModel>(
//     DataRef ref,
//     TModel Function(Map<String, dynamic> data) fromJson, {
//     Object? ascendByField,
//     Object? descendByField,
//     int? limit,
//   }) {
//     // Similar to streamModel, we simulate streaming with polling
//     return Stream<TModel?>.periodic(const Duration(seconds: 5))
//         .asyncMap((_) => _readModelCollection(ref, fromJson));
//   }

//   @override
//   Async<None> deleteCollection({required DataRef collectionRef}) {
//     throw UnimplementedError();
//     // final url = Uri.parse('${_getBaseURL()}/${collectionRef.collectionPath}');
//     // final response = await _httpClient.delete(url, headers: _authHeaders());
//     // if (response.statusCode != 200) {
//     //   throw Exception('Failed to delete collection: ${response.reasonPhrase}');
//     // }
//   }

//   Async<TModel> _readModel<TModel extends ReferencedModel>(
//     DataRef ref,
//     TModel Function(Map<String, dynamic> data) fromJson,
//   ) {
//     return Async(() async {
//       final url = Uri.parse('${_getBaseURL()}/${ref.path}');
//       final response = await _httpClient.get(url, headers: _authHeaders);
//       if (response.statusCode == 200) {
//         final responseModel = FirestoreDocModel.fromJsonStringOrNull(response.body);
//         final fields = responseModel?.fields;
//         if (fields == null) {
//           throw Err(
//             debugPath: ['FirestoreRESTServiceBroker', '_readModel'],
//             error: 'Failed to read model. No fields!',
//           );
//         }
//         return fromJson(convertToLocalJson(fields));
//       }
//       throw Err(
//         debugPath: const ['FirestoreRESTServiceBroker', '_readModel'],
//         error: '(${response.statusCode}) Failed to read model!',
//       );
//     });
//   }

//   // Helper method to read a collection of models
//   Future<Iterable<TModel>> _readModelCollection<TModel extends ReferencedModel>(
//     DataRef ref,
//     TModel Function(Map<String, dynamic> data) fromJson,
//   ) async {
//     throw UnimplementedError();
//     // final url = Uri.parse('${_getBaseURL()}/${ref.collectionPath}');
//     // final response = await _httpClient.get(url, headers: _authHeaders());
//     // if (response.statusCode == 200) {
//     //   final data = jsonDecode(response.body);
//     //   final documents = data['documents'] as List<dynamic>;
//     //   return documents
//     //       .map((doc) => fromJsonOrNull(doc['fields'] as Map<String, dynamic>))
//     //       .whereType<TModel>();
//     // }
//     // throw Exception('Failed to read collection: ${response.reasonPhrase}');
//   }

//   @override
//   Async<None> mergeModel<TModel extends ReferencedModel>(TModel model) {
//     return Async(() async {
//       final modelJson = model.toJson();
//       final updateMask = modelJson.keys.map((key) => 'updateMask.fieldPaths=$key').join('&');
//       final url = Uri.parse('${_getBaseURL()}/${model.ref!.path}?$updateMask');
//       final responseModel = FirestoreDocModel(fields: modelJson);
//       final body = responseModel.toFirestoreJsonString();

//       final response = await _httpClient.patch(
//         url,
//         headers: _authHeaders,
//         body: body,
//       );
//       if (response.statusCode != 200) {
//         throw Err(
//           debugPath: const ['FirestoreRESTServiceBroker', 'mergeModel'],
//           error: '(${response.statusCode}) Failed to merge model: ${response.body}',
//         );
//       }
//       return const None();
//     });
//   }

//   @override
//   Async<None> overwriteModel<TModel extends ReferencedModel>(TModel model) {
//     return mergeModel(model);
//   }

//   @override
//   Async<None> updateModel<TModel extends ReferencedModel>(TModel model) {
//     return mergeModel(model);
//   }

//   @override
//   Async<None> createModel<TModel extends ReferencedModel>(TModel model) {
//     return Async(() async {
//       final url = Uri.parse(
//         '${_getBaseURL()}/${model.ref!.collectionPath}?documentId=${model.ref!.id}',
//       );
//       final doc = FirestoreDocModel(fields: model.toJson());

//       final response = await _httpClient.post(
//         url,
//         headers: _authHeaders,
//         body: doc.toFirestoreJsonString(),
//       );

//       if (response.statusCode != 200) {
//         throw Err(
//           debugPath: const ['FirestoreRESTServiceBroker', 'mergeModel'],
//           error: '(${response.statusCode}) Failed to create model!',
//         );
//       }
//       return const None();
//     });
//   }

//   @override
//   Async<TModel> readModel<TModel extends ReferencedModel>(
//     DataRef ref,
//     TModel Function(Map<String, dynamic> data) fromJson,
//   ) {
//     return _readModel(ref, fromJson);
//   }

//   @override
//   Async<None> deleteModel(DataRef ref) {
//     return Async(() async {
//       final url = Uri.parse('${_getBaseURL()}/${ref.path}');
//       final response = await _httpClient.delete(url, headers: _authHeaders);
//       if (response.statusCode != 200) {
//         throw Err(
//           debugPath: const ['FirestoreRESTServiceBroker', 'deleteModel'],
//           error: '(${response.statusCode}) Failed to delete model!',
//         );
//       }
//       return const None();
//     });
//   }

//   @override
//   Async<None> runTransaction(
//     Future<void> Function(TransactionInterface broker) transactionHandler,
//   ) {
//     throw UnimplementedError();
//   }

//   @override
//   Async<Iterable<ReferencedModel>> runBatchOperations(
//     Iterable<BatchOperation<ReferencedModel>> operations,
//   ) {
//     throw UnimplementedError();
//   }
// }

// Map<String, dynamic> _buildStructuredQuery({
//   required String collectionId,
//   List<Map<String, dynamic>>? filters, // Accepts maps from Filter.toMap()
//   String? orderByField,
//   OrderDirection orderDirection = OrderDirection.ASCENDING,
//   int? limit,
// }) {
//   final query = <String, dynamic>{
//     'from': [
//       {
//         'collectionId': collectionId,
//       },
//     ],
//   };

//   // TODO: CREATE A MODEL FOR THIS:!!!

//   if (filters != null && filters.isNotEmpty) {
//     query['where'] = {
//       'compositeFilter': {
//         'op': 'AND', // OR???
//         'filters': filters.map((filter) {
//           return {
//             'fieldFilter': {
//               'field': {'fieldPath': filter['field']},
//               'op': filter['op'],
//               'value': convertToFirestoreValue(filter['value']),
//             },
//           };
//         }).toList(),
//       },
//     };
//   }
//   if (orderByField != null) {
//     query['orderBy'] = [
//       {
//         'field': {'fieldPath': orderByField},
//         'direction': orderDirection.name,
//       }
//     ];
//   }
//   if (limit != null) {
//     query['limit'] = limit;
//   }

//   return query;
// }

// // https://firebase.google.com/docs/firestore/reference/rest/v1/StructuredQuery

// enum WhereOp {
//   ARRAY_CONTAINS_ANY,
//   ARRAY_CONTAINS,
//   EQUAL,
//   GREATER_THAN_OR_EQUAL,
//   GREATER_THAN,
//   IN,
//   LESS_THAN_OR_EQUAL,
//   LESS_THAN,
//   NOT_EQUAL,
//   NOT_IN,
// }

// enum OrderDirection {
//   ASCENDING,
//   DESCENDING,
// }

// class Filter {
//   final String field;
//   final WhereOp op;
//   final dynamic value;

//   Filter({
//     required this.field,
//     required this.op,
//     required this.value,
//   });

//   // Convert the Filter object to a map for use in the query
//   Map<String, dynamic> toMap() {
//     return {
//       'field': field,
//       'op': op.name,
//       'value': value,
//     };
//   }
// }
