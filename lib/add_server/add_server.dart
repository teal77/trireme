/*
 * Trireme for Deluge - A Deluge thin client for Android.
 * Copyright (C) 2018  Aashrava Holla
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:trireme/common/common.dart';
import 'add_server_controller.dart';

class AddServerPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(Strings.addServerTitle),
        ),
        body: LoadingContainer(child: _AddServerPageContent()));
  }
}

class _AddServerPageContent extends StatefulWidget {
  @override
  State<_AddServerPageContent> createState() => _AddServerState();
}

class _AddServerState extends State<_AddServerPageContent>
    with TriremeProgressBarMixin {
  AddServerController controller = AddServerController();
  bool loading = false;

  String host;
  String port;
  String username;
  String password;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    showProgressBarIf(loading);

    return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(child: Builder(builder: (context) {
          return Column(
            children: <Widget>[
              TextFormField(
                decoration:
                    InputDecoration(labelText: Strings.addServerHostLabel),
                keyboardType: TextInputType.url,
                onSaved: (s) => host = s,
                validator: controller.validateHost,
              ),
              SizedBox(
                height: 16.0,
              ),
              TextFormField(
                initialValue: "58846",
                decoration:
                    InputDecoration(labelText: Strings.addServerPortLabel),
                keyboardType: TextInputType.number,
                onSaved: (s) => port = s,
                validator: controller.validatePort,
              ),
              SizedBox(
                height: 16.0,
              ),
              TextFormField(
                decoration: InputDecoration(
                    labelText: Strings.addServerUsernameLabel),
                onSaved: (s) => username = s,
                validator: controller.validateUsername,
              ),
              SizedBox(
                height: 16.0,
              ),
              PasswordField(
                labelText: Strings.addServerPasswordLabel,
                onSaved: (s) => password = s,
                validator: controller.validatePassword,
              ),
              SizedBox(
                height: 32.0,
              ),
              RaisedButton(
                child: Text(Strings.addServerAddServerButtonText),
                onPressed: loading ? null : () => onAddServerClicked(context),
              )
            ],
          );
        })));
  }

  void onAddServerClicked(BuildContext context) async {
    if (Form.of(context).validate()) {
      Form.of(context).save();
      await validateAndSaveServerCredentials(context);
    }
  }

  Future validateAndSaveServerCredentials(BuildContext scaffoldContext) async {
    setState(() => loading = true);

    try {
      if (await controller.validateServerCredentials(
          username, password, host, port)) {
        showSnackbar(scaffoldContext, Strings.strSuccess);
        await controller.addServer(username, password, host, port);
        await Future.delayed(const Duration(seconds: 1));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (e is String) {
        showSnackbar(scaffoldContext, e);
      } else {
        rethrow;
      }
    } finally {
      setState(() => loading = false);
    }
  }

  void showSnackbar(BuildContext scaffoldContext, String message) {
    Scaffold.of(scaffoldContext)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
      ));
  }
}

//Copied from https://github.com/flutter/flutter/blob/7a6a65a597581c44d99fd7deeaf2405432aeec8b/examples/flutter_gallery/lib/demo/material/text_form_field_demo.dart
class PasswordField extends StatefulWidget {
  const PasswordField({
    this.hintText,
    this.labelText,
    this.helperText,
    this.onSaved,
    this.validator,
    this.onFieldSubmitted,
  });

  final String hintText;
  final String labelText;
  final String helperText;
  final FormFieldSetter<String> onSaved;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onFieldSubmitted;

  @override
  _PasswordFieldState createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      obscureText: _obscureText,
      onSaved: widget.onSaved,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        hintText: widget.hintText,
        labelText: widget.labelText,
        helperText: widget.helperText,
        suffixIcon: GestureDetector(
          onTap: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
          child:
              Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
        ),
      ),
    );
  }
}
