import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════
class TC {
  static const bg = Color(0xFFFAF8F4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceWarm = Color(0xFFF7F4EE);
  static const border = Color(0xFFE8E3D8);
  static const borderLight = Color(0xFFF0ECE4);

  static const accent = Color(0xFFC25A2A);
  static const accentLight = Color(0xFFFAEDE5);
  static const accentMid = Color(0xFFD97B47);

  static const acBlue = Color(0xFF1A6BB5);
  static const acBlueBg = Color(0xFFE8F2FC);
  static const nonAcAmber = Color(0xFFB8730A);
  static const nonAcBg = Color(0xFFFFF4DC);
  static const rooftopTeal = Color(0xFF1A8070);
  static const rooftopBg = Color(0xFFE4F5F2);
  static const gardenGreen = Color(0xFF2E7D32);
  static const gardenBg = Color(0xFFE8F5E9);
  static const privatePurp = Color(0xFF6B3FA0);
  static const privateBg = Color(0xFFF3EBF9);

  static const available = Color(0xFF2E7D32);
  static const availableBg = Color(0xFFE8F5E9);
  static const occupied = Color(0xFFC25A2A);
  static const occupiedBg = Color(0xFFFAEDE5);
  static const reserved = Color(0xFF1A6BB5);
  static const reservedBg = Color(0xFFE8F2FC);
  static const cleaning = Color(0xFF888898);
  static const cleaningBg = Color(0xFFF3F3F8);

  static const textPri = Color(0xFF1E1A14);
  static const textSec = Color(0xFF7A705E);
  static const textMute = Color(0xFFB0A898);
  static const divider = Color(0xFFEEE9E0);
}

// ── Section / Status helpers ──────────────────────────────────
Color sectionColor(TableSection s) {
  switch (s) {
    case TableSection.ac:
      return TC.acBlue;
    case TableSection.nonAc:
      return TC.nonAcAmber;
    case TableSection.rooftop:
      return TC.rooftopTeal;
    case TableSection.garden:
      return TC.gardenGreen;
    case TableSection.privateRoom:
      return TC.privatePurp;
  }
}

Color sectionBg(TableSection s) {
  switch (s) {
    case TableSection.ac:
      return TC.acBlueBg;
    case TableSection.nonAc:
      return TC.nonAcBg;
    case TableSection.rooftop:
      return TC.rooftopBg;
    case TableSection.garden:
      return TC.gardenBg;
    case TableSection.privateRoom:
      return TC.privateBg;
  }
}

Color statusColor(TableStatus s) {
  switch (s) {
    case TableStatus.available:
      return TC.available;
    case TableStatus.occupied:
      return TC.occupied;
    case TableStatus.reserved:
      return TC.reserved;
    case TableStatus.cleaning:
      return TC.cleaning;
  }
}

Color statusBg(TableStatus s) {
  switch (s) {
    case TableStatus.available:
      return TC.availableBg;
    case TableStatus.occupied:
      return TC.occupiedBg;
    case TableStatus.reserved:
      return TC.reservedBg;
    case TableStatus.cleaning:
      return TC.cleaningBg;
  }
}

extension StringExt on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}