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

import 'package:flutter/material.dart';

import 'package:trireme/common/common.dart';

typedef void OnLabelSelected(String label);

class LabelButton extends StatelessWidget {
  final String tooltip;
  final TriremeRepository repository;
  final OnLabelSelected labelSelectedCallback;

  LabelButton(this.repository, this.tooltip, this.labelSelectedCallback);

  @override
  Widget build(BuildContext context) {
    Widget getNoLabelButton() {
      return IconButton(
        icon: const Icon(Icons.label_outline),
        tooltip: tooltip,
        onPressed: () {},
      );
    }

    return FutureBuilder<List<String>>(
      future: repository.getLabels(),
      initialData: [],
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          if (snapshot.data.isEmpty) {
            return getNoLabelButton();
          } else {
            return PopupMenuButton<String>(
              icon: const Icon(Icons.label_outline),
              tooltip: tooltip,
              itemBuilder: (context) => List<PopupMenuEntry<String>>.from(
                  snapshot.data.map((s) => PopupMenuItem<String>(
                        value: s,
                        child: Text(s),
                      )))
                ..add(PopupMenuDivider())
                ..add(PopupMenuItem<String>(
                  value: "",
                  child: Text(Strings.detailNoLabel),
                )),
              onSelected: labelSelectedCallback,
            );
          }
        } else if (snapshot.hasError) {
          return getNoLabelButton();
        }
      },
    );
  }
}
