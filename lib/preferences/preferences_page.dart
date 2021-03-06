import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sendmany/common/models/models.dart';
import 'package:sendmany/common/pages/retrieve_connection_info_page.dart';
import 'package:sendmany/common/utils.dart';
import 'package:sendmany/common/widgets/widgets.dart';
import 'package:sendmany/preferences/bloc.dart';

class PreferencesPage extends StatefulWidget {
  PreferencesPage({Key key}) : super(key: key);

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder(
        bloc: BlocProvider.of<PreferencesBloc>(context),
        builder: (BuildContext context, PreferencesState state) {
          return Scaffold(
            body: Center(
              child: Column(
                children: <Widget>[
                  ListTile(
                    title: TranslatedText('prefs.language_label'),
                    trailing: DropdownButton(
                      value: state.language,
                      onChanged: (value) {
                        BlocProvider.of<PreferencesBloc>(context).add(
                          ChangeLanguageEvent(languageCode: value),
                        );
                      },
                      items: _getLanguageItems(),
                    ),
                  ),
                  Divider(),
                  ListTile(
                    title: TranslatedText('prefs.theme_label'),
                    trailing: DropdownButton(
                      value: state.theme,
                      onChanged: (value) {
                        BlocProvider.of<PreferencesBloc>(context).add(
                          ChangeThemeEvent(theme: value),
                        );
                      },
                      items: _getThemeItems(),
                    ),
                  ),
                  Divider(),
                  ListTile(
                    title: TranslatedText('prefs.node_dropdown'),
                    trailing: DropdownButton<String>(
                      value: state.activeConnection.name,
                      onChanged: (value) {
                        BlocProvider.of<PreferencesBloc>(context).add(
                          ChangeActiveConnectionEvent(value),
                        );
                      },
                      items: _buildNodeItems(state.connections),
                    ),
                  ),
                  Spacer(),
                  Text(
                    '0.6.0-beta-rc2',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.caption,
                  ),
                ],
              ),
            ),
          );
        });
  }

  List<DropdownMenuItem<String>> _getLanguageItems() {
    var l = <String>['en', 'de', 'nb'].map<DropdownMenuItem<String>>(
      (String value) {
        var data = getLanguageCodeDisplayData(value);
        return DropdownMenuItem<String>(
          value: value,
          child: Row(children: [
            SizedBox(
              width: 15,
              height: 15,
              child: data.flag,
            ),
            Container(width: 8),
            Text(data.name)
          ]),
        );
      },
    ).toList();
    return l;
  }

  List<DropdownMenuItem<String>> _getThemeItems() {
    return [
      'SendMany',
      'Dark',
      'Light',
    ].map<DropdownMenuItem<String>>(
      (String value) {
        return DropdownMenuItem<String>(
          value: value.toLowerCase(),
          child: Text(value),
        );
      },
    ).toList();
  }

  List<DropdownMenuItem<String>> _buildNodeItems(
    List<LndConnectionData> connections,
  ) {
    var l = connections.map<DropdownMenuItem<String>>(
      (LndConnectionData data) {
        return DropdownMenuItem<String>(
          value: data.name,
          child: Text(data.name),
        );
      },
    ).toList();
    l.add(
      DropdownMenuItem<String>(
        value: 'add_node',
        child: RaisedButton(
          child: TranslatedText('prefs.add_node_btn'),
          onPressed: () {
            _navigateToAddRemoteNode();
          },
        ),
      ),
    );
    return l;
  }

  void _navigateToAddRemoteNode() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) {
        return BlocProvider.value(
          value: BlocProvider.of<PreferencesBloc>(context),
          child: RetrieveConnectionInfoPage(doScan: true),
        );
      }),
    );
  }
}
