import 'package:flutter/material.dart';

Text smallTextBlack(String text, Color TextColors) {
  return Text(
    text,
    style: TextStyle(
        fontSize: 12,
        fontFamily: 'Grotesk',
        color: TextColors,
        fontWeight: FontWeight.bold),
  );
}

Text btnTextBlack(String text, Color TextColors) {
  return Text(
    text,
    style: TextStyle(
        fontSize: 14,
        fontFamily: 'Grotesk',
        color: TextColors,
        fontWeight: FontWeight.bold),
  );
}

Text mediumTextBlack(String text, Color TextColors) {
  return Text(
    text,
    style: TextStyle(
        fontSize: 18,
        fontFamily: 'Grotesk',
        color: TextColors,
        fontWeight: FontWeight.bold),
  );
}