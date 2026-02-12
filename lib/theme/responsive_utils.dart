import 'package:flutter/material.dart';

class ResponsiveUtil {
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;

  void init(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    screenWidth = mediaQuery.size.width;
    screenHeight = mediaQuery.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;

    final double safeAreaHorizontal = mediaQuery.padding.left + mediaQuery.padding.right;
    final double safeAreaVertical = mediaQuery.padding.top + mediaQuery.padding.bottom;
    safeBlockHorizontal = (screenWidth - safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - safeAreaVertical) / 100;
  }

  // Responsive width based on percentage of screen width
  static double wp(double percentage) {
    return blockSizeHorizontal * percentage;
  }

  // Responsive height based on percentage of screen height
  static double hp(double percentage) {
    return blockSizeVertical * percentage;
  }

  // Responsive font size
  static double sp(double size) {
    return size * (screenWidth / 375); // 375 is base width (iPhone X)
  }
}

// Extension for easier access
extension SizeExtension on num {
  double get w => ResponsiveUtil.wp(toDouble());
  double get h => ResponsiveUtil.hp(toDouble());
  double get sp => ResponsiveUtil.sp(toDouble());
}