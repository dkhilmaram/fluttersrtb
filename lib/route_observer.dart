import 'package:flutter/material.dart';

/// Global RouteObserver shared across the app.
/// Import this file wherever RouteAware is used.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();