import 'package:flutter/material.dart';
import '../../features/transactions/domain/transaction.dart';

IconData getPaymentMethodIcon(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => Icons.payments_outlined,
  PaymentMethod.ewallet => Icons.phone_android_outlined,
  PaymentMethod.bank => Icons.account_balance_outlined,
};

String getPaymentMethodLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => 'Cash',
  PaymentMethod.ewallet => 'E-Wallet',
  PaymentMethod.bank => 'Bank',
};
