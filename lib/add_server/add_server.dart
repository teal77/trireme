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

import 'package:trireme_client/trireme_client.dart';

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
  var hostDetailsFormKey = GlobalKey<FormState>();
  var userDetailsFormKey = GlobalKey<FormState>();

  var controller = AddServerController();
  var loading = false;

  String? host;
  String? port;
  DaemonDetails? daemonDetails;
  var saveCertificate = false;
  String? username;
  String? password;

  var currentStep = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    showProgressBarIf(loading);

    return Stepper(
      steps: [
        Step(
            title: Text(Strings.addServerHostDetailsTitle),
            content: Form(
                key: hostDetailsFormKey,
                child: Column(
                  children: <Widget>[
                    TextFormField(
                      decoration: InputDecoration(
                          labelText: Strings.addServerHostLabel),
                      keyboardType: TextInputType.url,
                      onSaved: (s) => host = s,
                      validator: controller.validateHost,
                    ),
                    Container(
                      height: 16.0,
                    ),
                    TextFormField(
                      initialValue: "58846",
                      decoration: InputDecoration(
                          labelText: Strings.addServerPortLabel),
                      keyboardType: TextInputType.number,
                      onSaved: (s) => port = s,
                      validator: controller.validatePort,
                    ),
                  ],
                )),
            state: getStepState(0)),
        Step(
            title: Text(Strings.addServerCertDetailsTitle),
            content: Column(
              children: <Widget>[
                ListTile(
                  title: Text(Strings.addServerPublicKeyLabel),
                  subtitle: Text(
                      controller.getDaemonCertificatePubKey(daemonDetails)),
                ),
                ListTile(
                  title: Text(Strings.addServerCertificateIssuer),
                  subtitle: Text(
                    controller.getDaemonCertificateIssuer(daemonDetails),
                  ),
                ),
                SwitchListTile(
                  value: saveCertificate,
                  onChanged: (value) {
                    setState(() {
                      saveCertificate = !saveCertificate;
                    });
                  },
                  title: Text(Strings.addServerSaveCertificate),
                  subtitle: Text(Strings.addServerSaveCertificateInfo),
                )
              ],
            ),
            state: getStepState(1)),
        Step(
            title: Text(Strings.addServerUserDetailsTitle),
            content: Form(
                key: userDetailsFormKey,
                child: Column(
                  children: <Widget>[
                    TextFormField(
                      decoration: InputDecoration(
                          labelText: Strings.addServerUsernameLabel),
                      keyboardType: TextInputType.emailAddress,
                      onSaved: (s) => username = s,
                      validator: controller.validateUsername,
                    ),
                    Container(
                      height: 16.0,
                    ),
                    PasswordField(
                      labelText: Strings.addServerPasswordLabel,
                      onSaved: (s) => password = s,
                      validator: controller.validatePassword,
                    ),
                  ],
                )),
            state: getStepState(2))
      ],
      currentStep: currentStep,
      onStepContinue: loading ? null : onStepContinue,
    );
  }

  StepState getStepState(int step) {
    if (step == currentStep) {
      return StepState.editing;
    } else if (step < currentStep) {
      return StepState.complete;
    }
    return StepState.indexed;
  }

  void onStepContinue() async {
    if (currentStep == 0) {
      if (hostDetailsFormKey.currentState?.validate() ?? false) {
        hostDetailsFormKey.currentState?.save();
        detectDaemonAndContinue();
      }
    } else if (currentStep == 1) {
      setState(() {
        currentStep = 2;
      });
    } else if (currentStep == 2) {
      if (userDetailsFormKey.currentState?.validate() ?? false) {
        userDetailsFormKey.currentState?.save();
        validateAndSaveServerCredentials();
      }
    }
  }

  void detectDaemonAndContinue() async {
    setState(() {
      loading = true;
    });
    try {
      var daemonDetails =
          await TriremeClient.detectDaemon(host!, int.parse(port!));
      setState(() {
        currentStep = 1;
        this.daemonDetails = daemonDetails;
      });
    } catch (e) {
      showSnackBar(prettifyError(e));
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  void validateAndSaveServerCredentials() async {
    setState(() {
      loading = true;
    });
    try {
      var valid = await controller.validateServerCredentials(
          username!, password!, host!, port!);
      if (valid) {
        showSnackBar(Strings.strSuccess);
        var pemCert =
            saveCertificate ? daemonDetails?.daemonCertificate.pem : null;
        await controller.addServer(username!, password!, host!, port!, pemCert);
        await Future<void>.delayed(const Duration(seconds: 1));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      showSnackBar(e.toString());
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context)
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

  final String? hintText;
  final String? labelText;
  final String? helperText;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

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
          child: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
        ),
      ),
    );
  }
}
