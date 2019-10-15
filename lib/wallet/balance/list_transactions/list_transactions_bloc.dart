import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:grpc/grpc.dart';
import 'package:sendmany/common/connection/connection_manager/bloc.dart';
import 'package:sendmany/common/models/models.dart';
import 'package:sendmany/common/connection/lnd_rpc/lnd_rpc.dart' as lngrpc;
import 'package:sendmany/wallet/balance/bloc/bloc.dart';
import 'package:sendmany/wallet/balance/bloc/ln_info_bloc.dart';

import 'list_transactions_event.dart';
import 'list_transactions_state.dart';

// Event when a new message from the update subscription is received
class _SubscribeTransactionEvent extends ListTxEvent {
  final lngrpc.Transaction tx;

  _SubscribeTransactionEvent(this.tx);

  @override
  List<Object> get props => [tx];
}

class ListTxBloc extends Bloc<ListTxEvent, ListTxState> {
  LnInfoBloc _lnInfoBloc;
  List<TxLightningInvoice> invoices;
  List<TxLightningPayment> payments;
  List<TxOnchain> onchains = [];

  bool includeLightningInvoices = true;
  bool includeLightningPayments = true;
  bool includeOnchainTx = true;
  bool onlySettled = false;
  bool reversed = true;

  ResponseStream<lngrpc.Transaction> _responseStream;
  int pollInterval = 0;
  Timer _timer;
  int _lastBlockHight = 0;
  bool _checkingBlockHeight = false;

  ListTxBloc(LnInfoBloc lnInfoBloc) {
    _lnInfoBloc = lnInfoBloc;
    _setupTransactionSubscription();
  }

  @override
  void dispose() {
    if (_timer != null && _timer.isActive) {
      _timer.cancel();
    }

    super.dispose();
  }

  void _setupTransactionSubscription() {
    var client = LnConnectionDataProvider().lightningClient;
    var macaroon = LnConnectionDataProvider().macaroon;

    var opts = CallOptions(metadata: {
      "macaroon": macaroon,
    });

    lngrpc.GetTransactionsRequest req = lngrpc.GetTransactionsRequest();
    _responseStream = client.subscribeTransactions(
      req,
      options: opts,
    );
    _responseStream.listen((onData) {
      _lnInfoBloc.dispatch(LoadLnInfo());
      dispatch(_SubscribeTransactionEvent(onData));
    });
  }

  _setupTimer() {
    if (_timer != null && _timer.isActive) {
      _timer.cancel();
    }

    _timer = Timer.periodic(Duration(seconds: pollInterval), (timer) {
      if (pollInterval == 0) {
        _timer.cancel();
        _timer = null;
      } else {
        _checkBlockHeight();
      }
    });
  }

  Future _checkBlockHeight() async {
    if (_checkingBlockHeight) {
      return;
    }
    _checkingBlockHeight = true;
    var client = LnConnectionDataProvider().lightningClient;
    var macaroon = LnConnectionDataProvider().macaroon;

    var opts = CallOptions(metadata: {
      "macaroon": macaroon,
    });

    lngrpc.GetInfoRequest req = lngrpc.GetInfoRequest();
    lngrpc.GetInfoResponse info = await client.getInfo(
      req,
      options: opts,
    );

    if (info.blockHeight != _lastBlockHight) {
      _lnInfoBloc.dispatch(LoadLnInfo());
      dispatch(LoadTxEvent());
      _lastBlockHight = info.blockHeight;
    }
    _checkingBlockHeight = false;
  }

  @override
  ListTxState get initialState => InitialListTxState();

  @override
  Stream<ListTxState> mapEventToState(
    ListTxEvent event,
  ) async* {
    if (event is ChangePollTxIntervalEvent) {
      pollInterval = event.seconds;
      _setupTimer();
    } else if (event is SetFilterTxEvent) {
      includeLightningInvoices = event.includeLightningInvoices;
      includeLightningPayments = event.includeLightningPayments;
      includeOnchainTx = event.includeOnchainTx;
      onlySettled = event.onlySettled;
      reversed = event.reversed;
      yield _buildTxList();
    } else if (event is ResetFilterTxEvent) {
      includeLightningInvoices = true;
      includeLightningPayments = true;
      includeOnchainTx = true;
      onlySettled = false;
      reversed = true;
      yield _buildTxList();
    } else if (event is LoadTxEvent) {
      if (currentState is LoadingTxFinishedState) {
        LoadingTxFinishedState tx = currentState;
        yield LoadingTxState(tx.transactions);
      } else {
        yield LoadingTxState([]);
      }
      try {
        await _loadTransactions();
        yield _buildTxList();
      } catch (error) {
        yield LoadingTxErrorState(error);
      }
    } else if (event is _SubscribeTransactionEvent) {
      // check if it is an existing transaction
      bool found = false;
      OnchainTransaction newTx = OnchainTransaction.fromLND(event.tx);
      List<Tx> l = onchains.map((tx) {
        if (tx.tx.hash == newTx.hash) {
          // found the transaction, replace with new tx state
          found = true;
          return TxOnchain(newTx);
        } else {
          return tx;
        }
      }).toList();

      if (!found) {
        // we didn't find the tx, add it to the store
        l.add(TxOnchain(newTx));
      }
      onchains = l;
      yield _buildTxList();
    }
  }

  Future _loadTransactions() async {
    var client = LnConnectionDataProvider().lightningClient;

    lngrpc.ListInvoiceRequest invoicesRequest = lngrpc.ListInvoiceRequest();
    invoicesRequest.reversed = true;
    lngrpc.ListPaymentsRequest paymentsRequest = lngrpc.ListPaymentsRequest();
    lngrpc.GetTransactionsRequest txRequest = lngrpc.GetTransactionsRequest();

    var responseList = await Future.wait([
      client.listInvoices(invoicesRequest),
      client.listPayments(paymentsRequest),
      client.getTransactions(txRequest),
    ]);

    lngrpc.ListInvoiceResponse invoiceResponse = responseList[0];
    lngrpc.ListPaymentsResponse paymentsResponse = responseList[1];
    lngrpc.TransactionDetails txResponse = responseList[2];

    invoices = [];
    invoiceResponse.invoices.forEach((lngrpc.Invoice grpcInvoice) {
      Invoice invoice = Invoice.fromGRPC(grpcInvoice);
      invoices.add(TxLightningInvoice(invoice));
    });

    payments = [];
    paymentsResponse.payments.forEach((lngrpc.Payment grpcPayment) {
      Payment payment = Payment.fromGRPC(grpcPayment);
      payments.add(TxLightningPayment(payment));
    });

    onchains = [];
    txResponse.transactions.forEach((lngrpc.Transaction onChainTx) {
      if (onChainTx.amount != 0) {
        OnchainTransaction txm = OnchainTransaction.fromLND(onChainTx);
        onchains.add(TxOnchain(txm));
      }
    });
  }

  LoadingTxFinishedState _buildTxList() {
    List<Tx> tx = [];

    if (includeLightningInvoices) {
      invoices.forEach((TxLightningInvoice invoice) {
        if (onlySettled) {
          if (invoice.invoice.state == InvoiceState.settled) {
            tx.add(invoice);
          }
        } else {
          tx.add(invoice);
        }
      });
    }

    if (includeLightningPayments) {
      payments.forEach((TxLightningPayment payment) {
        if (onlySettled) {
          if (payment.payment.status == PaymentStatus.succeeded) {
            tx.add(payment);
          }
        } else {
          tx.add(payment);
        }
      });
    }

    if (includeOnchainTx) {
      onchains.forEach((TxOnchain onchainTx) {
        tx.add(onchainTx);
      });
    }

    tx.sort((Tx a, Tx b) {
      return b.date.compareTo(a.date);
    });

    return LoadingTxFinishedState(tx);
  }
}
