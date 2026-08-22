class PdrPoint {
  final double x;
  final double y;

  const PdrPoint({required this.x, required this.y});
}

class PdrPath {
  final List<PdrPoint> points = [];

  void addPoint(double x, double y) {
    points.add(PdrPoint(x: x, y: y));
  }

  void clear() {
    points.clear();
  }
}
