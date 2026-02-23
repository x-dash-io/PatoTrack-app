// Help Article model

import 'package:flutter/material.dart';

class HelpArticle {
  final String id;
  final String title;
  final String description;
  final String content;
  final IconData icon;
  final List<String>? steps;
  final List<String>? tips;

  HelpArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.icon,
    this.steps,
    this.tips,
  });
}
