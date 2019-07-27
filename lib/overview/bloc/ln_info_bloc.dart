import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:grpc/service_api.dart';
import 'package:torden/lightning/connection_manager/connection_data_provider.dart';
import 'package:torden/lightning/lnd/lnd_rpc.dart';
import 'ln_info_event.dart';
import 'ln_info_state.dart';

class LnInfoBloc extends Bloc<LnInfoEvent, LnInfoState> {
  @override
  LnInfoState get initialState => InitialLnInfoState();

  @override
  Stream<LnInfoState> mapEventToState(
    LnInfoEvent event,
  ) async* {
    if (event is LoadLnInfo) {
      var client = LnConnectionDataProvider().lightningClient;
      var macaroon = LnConnectionDataProvider().macaroon;
      yield LnInfoStateLoading();
      var infoRequest = GetInfoRequest();
      var walletBalanceRequest = WalletBalanceRequest();
      var channelBalanceRequest = ChannelBalanceRequest();
      var opts = CallOptions(metadata: {
        "macaroon": macaroon,
      });

      var responseList = await Future.wait([
        client.getInfo(infoRequest, options: opts),
        client.walletBalance(walletBalanceRequest, options: opts),
        client.channelBalance(channelBalanceRequest, options: opts),
      ]).catchError((error) {
        print(error);
      });

      yield LnInfoStateLoadingFinished(
        responseList[0],
        responseList[1],
        responseList[2],
      );
    }
  }
}
