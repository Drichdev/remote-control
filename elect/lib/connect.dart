import 'package:flutter/material.dart';

class RippleAnimation extends StatefulWidget {
  const RippleAnimation({Key? key}) : super(key: key);
  @override
  _RippleAnimationState createState() => _RippleAnimationState();
}

class _RippleAnimationState extends State<RippleAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 4),
    )..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < 4; i++)
            AnimatedBuilder(
              animation: _controller,
              child: SizedBox.expand(),
              builder: (context, child) {
                final progress = (_controller.value + i / 4) % 1;
                return CustomPaint(
                  painter: CirclePainter(progress),
                  child: child,
                );
              },
            ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(16),
            child: Icon(Icons.power, size: 50, color: Colors.blue),
          ),
        ],
      ),
    );
  }
}

class CirclePainter extends CustomPainter {
  final double progress;
  CirclePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final curved = Curves.easeOut.transform(progress);
    final paint = Paint()
      ..color = Colors.blue.withOpacity(1 - curved)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 + 2 * curved;

    final radius = size.width * curved / 2;
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CirclePainter old) =>
      old.progress != progress;
}
