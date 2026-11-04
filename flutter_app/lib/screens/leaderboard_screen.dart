import 'package:flutter/material.dart';

import '../widgets/arena_widgets.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Leaderboard')),
        body: ListView(padding: const EdgeInsets.all(16), children: const [
          Icon(Icons.leaderboard_outlined, size: 48, color: Color(0xFF55DCE5)),
          SizedBox(height: 18),
          Text('No live rankings available',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
          SizedBox(height: 10),
          ApiNotice(
              message:
                  'The repository contains static example leaderboard rows but no leaderboard API. They are intentionally not shown as real users or scores.'),
        ]),
      );
}
