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

import 'package:trireme_client/deserialization.dart';

import 'package:trireme/common/common.dart';
import 'package:trireme/torrent_list/torrent_list_controller.dart';

typedef FilterSelectedCallback = void Function(FilterSpec f);

class _Filter {
  String displayName;
  String filter;

  _Filter(this.displayName, this.filter);
}

Future showFilterBottomSheet(BuildContext context, Future<FilterTree> future,
    FilterSpec lastSelected, FilterSelectedCallback onFilterSelected) {
  return showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return FutureBuilder<FilterTree>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final stateFilters = List<_Filter>.from(snapshot
                    .data.statusFilters
                    .map((o) => (o as List).first as String)
                    .map<_Filter>((e) => _Filter(e, e)));
                final trackerFilters = List<_Filter>.from(snapshot
                    .data.trackerFilters
                    .map((o) => (o as List).first as String)
                    .map<_Filter>((e) => _Filter(e, e)));

                var labelFilters = <_Filter>[];
                if (snapshot.data.labelFilters != null) {
                  labelFilters = List<_Filter>.from(snapshot.data.labelFilters
                      .map((o) => (o as List).first as String)
                      .where((e) => e.isNotEmpty)
                      .map<_Filter>((e) => _Filter(e, e)));
                  labelFilters.add(_Filter(Strings.homeFilterNoLabel, ''));
                }

                return FilterSelector(stateFilters, labelFilters,
                    trackerFilters, lastSelected, onFilterSelected);
              } else if (snapshot.hasError) {
                return ErrorPage(snapshot.error);
              } else {
                return Align(
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(),
                );
              }
            });
      });
}

class FilterSelector extends StatefulWidget {
  final List<_Filter> stateFilters;
  final List<_Filter> labelFilters;
  final List<_Filter> trackerFilters;
  final FilterSpec lastSelected;
  final FilterSelectedCallback callback;

  FilterSelector(this.stateFilters, this.labelFilters, this.trackerFilters,
      this.lastSelected, this.callback);

  @override
  State<StatefulWidget> createState() {
    return _FilterSelectorState();
  }
}

class _FilterSelectorState extends State<FilterSelector> {
  String statusFilter;
  String labelFilter;
  String trackerFilter;

  @override
  void initState() {
    super.initState();
    statusFilter = widget.lastSelected.statusFilter;
    if (!widget.stateFilters.any((e) => e.filter == statusFilter)) {
      statusFilter = FilterSpec.strAll;
    }

    labelFilter = widget.lastSelected.labelFilter;
    if (!widget.labelFilters.any((e) => e.filter == labelFilter)) {
      labelFilter = FilterSpec.strAll;
    }

    trackerFilter = widget.lastSelected.trackerFilter;
    if (!widget.trackerFilters.any((e) => e.filter == trackerFilter)) {
      trackerFilter = FilterSpec.strAll;
    }

    dispatchCallbackWithFilterSpec(); //If some filters are now invalid
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            Strings.homeFilterByStatus,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.0),
          ),
          FilterChipContainer(
              widget.stateFilters, statusFilter, onStateFilterChanged),
          Text(
            Strings.homeFilterByLabel,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.0),
          ),
          FilterChipContainer(
              widget.labelFilters, labelFilter, onLabelFilterChanged),
          Text(
            Strings.homeFilterByTrackerHost,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.0),
          ),
          FilterChipContainer(
              widget.trackerFilters, trackerFilter, onTrackerFilterChanged),
        ],
      ),
    );
  }

  void onStateFilterChanged(String s) {
    statusFilter = s;
    dispatchCallbackWithFilterSpec();
  }

  void onLabelFilterChanged(String s) {
    labelFilter = s;
    dispatchCallbackWithFilterSpec();
  }

  void onTrackerFilterChanged(String s) {
    trackerFilter = s;
    dispatchCallbackWithFilterSpec();
  }

  void dispatchCallbackWithFilterSpec() {
    widget.callback(FilterSpec(statusFilter, labelFilter, trackerFilter));
  }
}

class FilterChipContainer extends StatefulWidget {
  final List<_Filter> choices;
  final String lastSelected;
  final ValueChanged<String> selectionChanged;

  FilterChipContainer(this.choices, this.lastSelected, this.selectionChanged);

  @override
  State<StatefulWidget> createState() {
    return _FilterChipContainerState();
  }
}

class _FilterChipContainerState extends State<FilterChipContainer> {
  String selectedChoice;

  @override
  void initState() {
    super.initState();
    selectedChoice = widget.lastSelected;
  }

  @override
  Widget build(BuildContext context) {
    var chipSelectedColor = Theme.of(context).brightness == Brightness.dark
        ? ChipTheme.of(context).selectedColor
        : ChipTheme.of(context).secondarySelectedColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: widget.choices
            .map((s) => ChoiceChip(
                  label: Text(s.displayName),
                  selectedColor: chipSelectedColor,
                  selected: selectedChoice == s.filter,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedChoice = s.filter;
                      });
                      widget.selectionChanged(s.filter);
                    }
                  },
                ))
            .toList(),
      ),
    );
  }
}

class FilterSpecContainer extends StatelessWidget {
  final FilterSpec filterSpec;
  final ValueChanged<FilterSpec> filterChangedCallback;

  FilterSpecContainer(this.filterSpec, this.filterChangedCallback);

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: (filterSpec == FilterSpec.all),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        alignment: Alignment.topLeft,
        child: Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: _getChildren(),
        ),
      ),
    );
  }

  List<Widget> _getChildren() {
    var children = <Widget>[];

    if (filterSpec.statusFilter != FilterSpec.strAll) {
      children.add(_getFilterChip(filterSpec.statusFilter, () {
        filterChangedCallback(FilterSpec(FilterSpec.strAll,
            filterSpec.labelFilter, filterSpec.trackerFilter));
      }));
    }

    if (filterSpec.labelFilter != FilterSpec.strAll) {
      var filter = filterSpec.labelFilter;
      if (filter.isEmpty) filter = Strings.homeFilterNoLabel;
      children.add(_getFilterChip(filter, () {
        filterChangedCallback(FilterSpec(filterSpec.statusFilter,
            FilterSpec.strAll, filterSpec.trackerFilter));
      }));
    }

    if (filterSpec.trackerFilter != FilterSpec.strAll) {
      children.add(_getFilterChip(filterSpec.trackerFilter, () {
        filterChangedCallback(FilterSpec(filterSpec.statusFilter,
            filterSpec.labelFilter, FilterSpec.strAll));
      }));
    }

    return children;
  }

  Widget _getFilterChip(String text, VoidCallback onDelete) {
    return InputChip(
      label: Text(text),
      deleteIcon: const Icon(
        Icons.close,
        size: 12.0,
      ),
      onDeleted: onDelete,
    );
  }
}
