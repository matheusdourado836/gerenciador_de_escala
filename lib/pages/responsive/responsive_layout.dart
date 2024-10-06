import 'package:flutter/material.dart';

class ResponsiveLayout extends StatefulWidget {
  final Widget mobileScreen;
  final Widget desktopScreen;
  const ResponsiveLayout({super.key, required this.mobileScreen, required this.desktopScreen});

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if(constraints.maxWidth < 1630) {
        return widget.mobileScreen;
      }else {
        return widget.desktopScreen;
      }
    });
  }
}