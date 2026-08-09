import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/invoice.dart';
import '../models/paginated.dart';

class InvoicesService {
  final Ref ref;
  InvoicesService(this.ref);

  Future<PaginatedResponse<InvoiceModel>> list(Map<String, dynamic> params) async {
    final res = await ref.read(dioProvider).get('/invoices', queryParameters: params);
    return PaginatedResponse.fromJson(res.data as Map<String, dynamic>, InvoiceModel.fromJson);
  }

  Future<InvoiceModel> get(int id) async {
    final res = await ref.read(dioProvider).get('/invoices/$id');
    return InvoiceModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}

final invoicesServiceProvider = Provider((ref) => InvoicesService(ref));
