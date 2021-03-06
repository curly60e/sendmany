import 'dart:async';
import 'dart:io';
import 'package:grpc/grpc.dart';
import 'package:sendmany/common/connection/check_lnd_connection/check_lnd_connection_event.dart';
import 'package:sendmany/common/connection/check_lnd_connection/check_lnd_connection_state.dart';
import 'package:sendmany/common/connection/lnd_rpc/lnd_rpc.dart';
import 'package:bloc/bloc.dart';

class CheckLndConnectionBloc
    extends Bloc<CheckLNDConnectionEvent, CheckLNDConnectionState> {
  ClientChannel _clientChannel;
  LightningClient _lightningClient;

  @override
  Future<void> close() async {
    await _clientChannel.shutdown();
    await super.close();
  }

  @override
  CheckLNDConnectionState get initialState => InitialCheckLNDConnectionState();

  @override
  Stream<CheckLNDConnectionState> mapEventToState(
    CheckLNDConnectionEvent event,
  ) async* {
    if (event is DoCheckLNDConnectionEvent) {
      yield CheckingLNDConnectionState();
      yield await _establishConnection(event);
    }
  }

  Future<CheckLNDConnectionState> _establishConnection(
      DoCheckLNDConnectionEvent event) async {
    final creds = ChannelCredentials.secure(
      certificates: event.data.certificate,
      onBadCertificate: (X509Certificate certificate, String host) {
        // Trust the certificate
        return true;
      },
    );

    final opts = CallOptions(
      metadata: {'macaroon': event.data.macaroon},
    );

    _clientChannel = ClientChannel(
      event.data.host,
      port: event.data.port,
      options: ChannelOptions(credentials: creds),
    );
    _lightningClient = LightningClient(
      _clientChannel,
      options: opts,
    );

    var infoRequest = GetInfoRequest();
    try {
      var response = await _lightningClient.getInfo(infoRequest, options: opts);
      return CheckLNDConnectionSuccessState(info: response);
    } catch (e) {
      return CheckLNDConnectionErrorState(error: e.toString());
    }
  }
}
