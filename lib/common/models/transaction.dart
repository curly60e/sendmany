import 'package:fixnum/fixnum.dart';
import 'package:torden/common/models/models.dart';

class Tx {
  final String memo;
  final Int64 amountSat;
  final DateTime date;

  Tx(this.memo, this.amountSat, this.date);
}

class TxLightningPayment extends Tx {
  final Payment payment;

  TxLightningPayment(this.payment)
      : super(payment.memo, payment.valueSat, payment.creationDate);
}

class TxLightningInvoice extends Tx {
  final Invoice invoice;

  TxLightningInvoice(this.invoice)
      : super(
          invoice.memo,
          invoice.state == InvoiceState.settled
              ? invoice.amtPaidSat
              : invoice.value,
          invoice.state == InvoiceState.settled
              ? invoice.settleDate
              : invoice.creationDate,
        );
}

class TxOnchain extends Tx {
  final OnchainTransaction tx;

  TxOnchain(this.tx, {memo: ""})
      : super(
          memo,
          tx.amount,
          tx.timsStampDateTime,
        );
}
