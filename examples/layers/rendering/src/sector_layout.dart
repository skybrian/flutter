// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';

const double kTwoPi = 2 * math.PI;

class SectorConstraints extends Constraints {
  const SectorConstraints({
    this.minDeltaRadius: 0.0,
    this.maxDeltaRadius: double.INFINITY,
    this.minDeltaTheta: 0.0,
    this.maxDeltaTheta: kTwoPi
  }) : assert(maxDeltaRadius >= minDeltaRadius),
       assert(maxDeltaTheta >= minDeltaTheta);

  const SectorConstraints.tight({ double deltaRadius: 0.0, double deltaTheta: 0.0 })
    : minDeltaRadius = deltaRadius,
      maxDeltaRadius = deltaRadius,
      minDeltaTheta = deltaTheta,
      maxDeltaTheta = deltaTheta;

  final double minDeltaRadius;
  final double maxDeltaRadius;
  final double minDeltaTheta;
  final double maxDeltaTheta;

  double constrainDeltaRadius(double deltaRadius) {
    return deltaRadius.clamp(minDeltaRadius, maxDeltaRadius);
  }

  double constrainDeltaTheta(double deltaTheta) {
    return deltaTheta.clamp(minDeltaTheta, maxDeltaTheta);
  }

  @override
  bool get isTight => minDeltaTheta >= maxDeltaTheta && minDeltaTheta >= maxDeltaTheta;

  @override
  bool get isNormalized => minDeltaRadius <= maxDeltaRadius && minDeltaTheta <= maxDeltaTheta;

  @override
  bool debugAssertIsValid({
    bool isAppliedConstraint: false,
    InformationCollector informationCollector
  }) {
    assert(isNormalized);
    return isNormalized;
  }
}

class SectorDimensions {
  const SectorDimensions({ this.deltaRadius: 0.0, this.deltaTheta: 0.0 });

  factory SectorDimensions.withConstraints(
    SectorConstraints constraints,
    { double deltaRadius: 0.0, double deltaTheta: 0.0 }
  ) {
    return new SectorDimensions(
      deltaRadius: constraints.constrainDeltaRadius(deltaRadius),
      deltaTheta: constraints.constrainDeltaTheta(deltaTheta)
    );
  }

  final double deltaRadius;
  final double deltaTheta;
}

class SectorParentData extends ParentData {
  double radius = 0.0;
  double theta = 0.0;
}

abstract class RenderSector extends RenderObject {

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SectorParentData)
      child.parentData = new SectorParentData();
  }

  // RenderSectors always use SectorParentData subclasses, as they need to be
  // able to read their position information for painting and hit testing.
  @override
  SectorParentData get parentData => super.parentData;

  SectorDimensions getIntrinsicDimensions(SectorConstraints constraints, double radius) {
    return new SectorDimensions.withConstraints(constraints);
  }

  @override
  SectorConstraints get constraints => super.constraints;

  @override
  void debugAssertDoesMeetConstraints() {
    assert(constraints != null);
    assert(deltaRadius != null);
    assert(deltaRadius < double.INFINITY);
    assert(deltaTheta != null);
    assert(deltaTheta < double.INFINITY);
    assert(constraints.minDeltaRadius <= deltaRadius);
    assert(deltaRadius <= math.max(constraints.minDeltaRadius, constraints.maxDeltaRadius));
    assert(constraints.minDeltaTheta <= deltaTheta);
    assert(deltaTheta <= math.max(constraints.minDeltaTheta, constraints.maxDeltaTheta));
  }

  @override
  void performResize() {
    // default behavior for subclasses that have sizedByParent = true
    deltaRadius = constraints.constrainDeltaRadius(0.0);
    deltaTheta = constraints.constrainDeltaTheta(0.0);
  }

  @override
  void performLayout() {
    // descendants have to either override performLayout() to set both
    // the dimensions and lay out children, or, set sizedByParent to
    // true so that performResize()'s logic above does its thing.
    assert(sizedByParent);
  }

  @override
  Rect get paintBounds => new Rect.fromLTWH(0.0, 0.0, 2.0 * deltaRadius, 2.0 * deltaRadius);

  @override
  Rect get semanticBounds => new Rect.fromLTWH(-deltaRadius, -deltaRadius, 2.0 * deltaRadius, 2.0 * deltaRadius);

  bool hitTest(HitTestResult result, { double radius, double theta }) {
    if (radius < parentData.radius || radius >= parentData.radius + deltaRadius ||
        theta < parentData.theta || theta >= parentData.theta + deltaTheta)
      return false;
    hitTestChildren(result, radius: radius, theta: theta);
    result.add(new HitTestEntry(this));
    return true;
  }
  void hitTestChildren(HitTestResult result, { double radius, double theta }) { }

  double deltaRadius;
  double deltaTheta;
}

abstract class RenderDecoratedSector extends RenderSector {

  RenderDecoratedSector(BoxDecoration decoration) : _decoration = decoration;

  BoxDecoration _decoration;
  BoxDecoration get decoration => _decoration;
  set decoration(BoxDecoration value) {
    if (value == _decoration)
      return;
    _decoration = value;
    markNeedsPaint();
  }

  // offset must point to the center of the circle
  @override
  void paint(PaintingContext context, Offset offset) {
    assert(deltaRadius != null);
    assert(deltaTheta != null);
    assert(parentData is SectorParentData);

    if (_decoration == null)
      return;

    if (_decoration.backgroundColor != null) {
      final Canvas canvas = context.canvas;
      final Paint paint = new Paint()..color = _decoration.backgroundColor;
      final Path path = new Path();
      final double outerRadius = (parentData.radius + deltaRadius);
      final Rect outerBounds = new Rect.fromLTRB(offset.dx-outerRadius, offset.dy-outerRadius, offset.dx+outerRadius, offset.dy+outerRadius);
      path.arcTo(outerBounds, parentData.theta, deltaTheta, true);
      final double innerRadius = parentData.radius;
      final Rect innerBounds = new Rect.fromLTRB(offset.dx-innerRadius, offset.dy-innerRadius, offset.dx+innerRadius, offset.dy+innerRadius);
      path.arcTo(innerBounds, parentData.theta + deltaTheta, -deltaTheta, false);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

}

class SectorChildListParentData extends SectorParentData with ContainerParentDataMixin<RenderSector> { }

class RenderSectorWithChildren extends RenderDecoratedSector with ContainerRenderObjectMixin<RenderSector, SectorChildListParentData> {
  RenderSectorWithChildren(BoxDecoration decoration) : super(decoration);

  @override
  void hitTestChildren(HitTestResult result, { double radius, double theta }) {
    RenderSector child = lastChild;
    while (child != null) {
      if (child.hitTest(result, radius: radius, theta: theta))
        return;
      final SectorChildListParentData childParentData = child.parentData;
      child = childParentData.previousSibling;
    }
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    RenderSector child = lastChild;
    while (child != null) {
      visitor(child);
      final SectorChildListParentData childParentData = child.parentData;
      child = childParentData.previousSibling;
    }
  }
}

class RenderSectorRing extends RenderSectorWithChildren {
  // lays out RenderSector children in a ring

  RenderSectorRing({
    BoxDecoration decoration,
    double deltaRadius: double.INFINITY,
    double padding: 0.0
  }) : _padding = padding,
       assert(deltaRadius >= 0.0),
       _desiredDeltaRadius = deltaRadius,
       super(decoration);

  double _desiredDeltaRadius;
  double get desiredDeltaRadius => _desiredDeltaRadius;
  set desiredDeltaRadius(double value) {
    assert(value != null);
    assert(value >= 0);
    if (_desiredDeltaRadius != value) {
      _desiredDeltaRadius = value;
      markNeedsLayout();
    }
  }

  double _padding;
  double get padding => _padding;
  set padding(double value) {
    // TODO(ianh): avoid code duplication
    assert(value != null);
    if (_padding != value) {
      _padding = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderObject child) {
    // TODO(ianh): avoid code duplication
    if (child.parentData is! SectorChildListParentData)
      child.parentData = new SectorChildListParentData();
  }

  @override
  SectorDimensions getIntrinsicDimensions(SectorConstraints constraints, double radius) {
    final double outerDeltaRadius = constraints.constrainDeltaRadius(desiredDeltaRadius);
    final double innerDeltaRadius = math.max(0.0, outerDeltaRadius - padding * 2.0);
    final double childRadius = radius + padding;
    final double paddingTheta = math.atan(padding / (radius + outerDeltaRadius));
    double innerTheta = paddingTheta; // increments with each child
    double remainingDeltaTheta = math.max(0.0, constraints.maxDeltaTheta - (innerTheta + paddingTheta));
    RenderSector child = firstChild;
    while (child != null) {
      final SectorConstraints innerConstraints = new SectorConstraints(
        maxDeltaRadius: innerDeltaRadius,
        maxDeltaTheta: remainingDeltaTheta
      );
      final SectorDimensions childDimensions = child.getIntrinsicDimensions(innerConstraints, childRadius);
      innerTheta += childDimensions.deltaTheta;
      remainingDeltaTheta -= childDimensions.deltaTheta;
      final SectorChildListParentData childParentData = child.parentData;
      child = childParentData.nextSibling;
      if (child != null) {
        innerTheta += paddingTheta;
        remainingDeltaTheta -= paddingTheta;
      }
    }
    return new SectorDimensions.withConstraints(constraints,
                                                deltaRadius: outerDeltaRadius,
                                                deltaTheta: innerTheta);
  }

  @override
  void performLayout() {
    assert(this.parentData is SectorParentData);
    deltaRadius = constraints.constrainDeltaRadius(desiredDeltaRadius);
    assert(deltaRadius < double.INFINITY);
    final double innerDeltaRadius = deltaRadius - padding * 2.0;
    final double childRadius = this.parentData.radius + padding;
    final double paddingTheta = math.atan(padding / (this.parentData.radius + deltaRadius));
    double innerTheta = paddingTheta; // increments with each child
    double remainingDeltaTheta = constraints.maxDeltaTheta - (innerTheta + paddingTheta);
    RenderSector child = firstChild;
    while (child != null) {
      final SectorConstraints innerConstraints = new SectorConstraints(
        maxDeltaRadius: innerDeltaRadius,
        maxDeltaTheta: remainingDeltaTheta
      );
      assert(child.parentData is SectorParentData);
      child.parentData.theta = innerTheta;
      child.parentData.radius = childRadius;
      child.layout(innerConstraints, parentUsesSize: true);
      innerTheta += child.deltaTheta;
      remainingDeltaTheta -= child.deltaTheta;
      final SectorChildListParentData childParentData = child.parentData;
      child = childParentData.nextSibling;
      if (child != null) {
        innerTheta += paddingTheta;
        remainingDeltaTheta -= paddingTheta;
      }
    }
    deltaTheta = innerTheta;
  }

  // offset must point to the center of our circle
  // each sector then knows how to paint itself at its location
  @override
  void paint(PaintingContext context, Offset offset) {
    // TODO(ianh): avoid code duplication
    super.paint(context, offset);
    RenderSector child = firstChild;
    while (child != null) {
      context.paintChild(child, offset);
      final SectorChildListParentData childParentData = child.parentData;
      child = childParentData.nextSibling;
    }
  }

}

class RenderSectorSlice extends RenderSectorWithChildren {
  // lays out RenderSector children in a stack

  RenderSectorSlice({
    BoxDecoration decoration,
    double deltaTheta: kTwoPi,
    double padding: 0.0
  }) : _padding = padding, _desiredDeltaTheta = deltaTheta, super(decoration);

  double _desiredDeltaTheta;
  double get desiredDeltaTheta => _desiredDeltaTheta;
  set desiredDeltaTheta(double value) {
    assert(value != null);
    if (_desiredDeltaTheta != value) {
      _desiredDeltaTheta = value;
      markNeedsLayout();
    }
  }

  double _padding;
  double get padding => _padding;
  set padding(double value) {
    // TODO(ianh): avoid code duplication
    assert(value != null);
    if (_padding != value) {
      _padding = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderObject child) {
    // TODO(ianh): avoid code duplication
    if (child.parentData is! SectorChildListParentData)
      child.parentData = new SectorChildListParentData();
  }

  @override
  SectorDimensions getIntrinsicDimensions(SectorConstraints constraints, double radius) {
    assert(this.parentData is SectorParentData);
    final double paddingTheta = math.atan(padding / this.parentData.radius);
    final double outerDeltaTheta = constraints.constrainDeltaTheta(desiredDeltaTheta);
    final double innerDeltaTheta = outerDeltaTheta - paddingTheta * 2.0;
    double childRadius = this.parentData.radius + padding;
    double remainingDeltaRadius = constraints.maxDeltaRadius - (padding * 2.0);
    RenderSector child = firstChild;
    while (child != null) {
      final SectorConstraints innerConstraints = new SectorConstraints(
        maxDeltaRadius: remainingDeltaRadius,
        maxDeltaTheta: innerDeltaTheta
      );
      final SectorDimensions childDimensions = child.getIntrinsicDimensions(innerConstraints, childRadius);
      childRadius += childDimensions.deltaRadius;
      remainingDeltaRadius -= childDimensions.deltaRadius;
      final SectorChildListParentData childParentData = child.parentData;
      child = childParentData.nextSibling;
      childRadius += padding;
      remainingDeltaRadius -= padding;
    }
    return new SectorDimensions.withConstraints(constraints,
                                                deltaRadius: childRadius - this.parentData.radius,
                                                deltaTheta: outerDeltaTheta);
  }

  @override
  void performLayout() {
    assert(this.parentData is SectorParentData);
    deltaTheta = constraints.constrainDeltaTheta(desiredDeltaTheta);
    assert(deltaTheta <= kTwoPi);
    final double paddingTheta = math.atan(padding / this.parentData.radius);
    final double innerTheta = this.parentData.theta + paddingTheta;
    final double innerDeltaTheta = deltaTheta - paddingTheta * 2.0;
    double childRadius = this.parentData.radius + padding;
    double remainingDeltaRadius = constraints.maxDeltaRadius - (padding * 2.0);
    RenderSector child = firstChild;
    while (child != null) {
      final SectorConstraints innerConstraints = new SectorConstraints(
        maxDeltaRadius: remainingDeltaRadius,
        maxDeltaTheta: innerDeltaTheta
      );
      child.parentData.theta = innerTheta;
      child.parentData.radius = childRadius;
      child.layout(innerConstraints, parentUsesSize: true);
      childRadius += child.deltaRadius;
      remainingDeltaRadius -= child.deltaRadius;
      final SectorChildListParentData childParentData = child.parentData;
      child = childParentData.nextSibling;
      childRadius += padding;
      remainingDeltaRadius -= padding;
    }
    deltaRadius = childRadius - this.parentData.radius;
  }

  // offset must point to the center of our circle
  // each sector then knows how to paint itself at its location
  @override
  void paint(PaintingContext context, Offset offset) {
    // TODO(ianh): avoid code duplication
    super.paint(context, offset);
    RenderSector child = firstChild;
    while (child != null) {
      assert(child.parentData is SectorChildListParentData);
      context.paintChild(child, offset);
      final SectorChildListParentData childParentData = child.parentData;
      child = childParentData.nextSibling;
    }
  }

}

class RenderBoxToRenderSectorAdapter extends RenderBox with RenderObjectWithChildMixin<RenderSector> {

  RenderBoxToRenderSectorAdapter({ double innerRadius: 0.0, RenderSector child }) :
    _innerRadius = innerRadius {
    this.child = child;
  }

  double _innerRadius;
  double get innerRadius => _innerRadius;
  set innerRadius(double value) {
    _innerRadius = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SectorParentData)
      child.parentData = new SectorParentData();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (child == null)
      return 0.0;
    return getIntrinsicDimensions(height: height).width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child == null)
      return 0.0;
    return getIntrinsicDimensions(height: height).width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (child == null)
      return 0.0;
    return getIntrinsicDimensions(width: width).height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (child == null)
      return 0.0;
    return getIntrinsicDimensions(width: width).height;
  }

  Size getIntrinsicDimensions({
    double width: double.INFINITY,
    double height: double.INFINITY
  }) {
    assert(child is RenderSector);
    assert(child.parentData is SectorParentData);
    assert(width != null);
    assert(height != null);
    if (!width.isFinite && !height.isFinite)
      return Size.zero;
    final double maxChildDeltaRadius = math.max(0.0, math.min(width, height) / 2.0 - innerRadius);
    final SectorDimensions childDimensions = child.getIntrinsicDimensions(new SectorConstraints(maxDeltaRadius: maxChildDeltaRadius), innerRadius);
    final double dimension = (innerRadius + childDimensions.deltaRadius) * 2.0;
    return new Size.square(dimension);
  }

  @override
  void performLayout() {
    if (child == null) {
      size = constraints.constrain(Size.zero);
    } else {
      assert(child is RenderSector);
      assert(constraints.maxWidth < double.INFINITY || constraints.maxHeight < double.INFINITY);
      final double maxChildDeltaRadius = math.min(constraints.maxWidth, constraints.maxHeight) / 2.0 - innerRadius;
      assert(child.parentData is SectorParentData);
      child.parentData.radius = innerRadius;
      child.parentData.theta = 0.0;
      child.layout(new SectorConstraints(maxDeltaRadius: maxChildDeltaRadius), parentUsesSize: true);
      final double dimension = (innerRadius + child.deltaRadius) * 2.0;
      size = constraints.constrain(new Size(dimension, dimension));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (child != null) {
      final Rect bounds = offset & size;
      // we move the offset to the center of the circle for the RenderSectors
      context.paintChild(child, bounds.center.toOffset());
    }
  }

  @override
  bool hitTest(HitTestResult result, { Point position }) {
    if (child == null)
      return false;
    double x = position.x;
    double y = position.y;
    // translate to our origin
    x -= size.width/2.0;
    y -= size.height/2.0;
    // convert to radius/theta
    final double radius = math.sqrt(x*x+y*y);
    final double theta = (math.atan2(x, -y) - math.PI/2.0) % kTwoPi;
    if (radius < innerRadius)
      return false;
    if (radius >= innerRadius + child.deltaRadius)
      return false;
    if (theta > child.deltaTheta)
      return false;
    child.hitTest(result, radius: radius, theta: theta);
    result.add(new BoxHitTestEntry(this, position));
    return true;
  }

}

class RenderSolidColor extends RenderDecoratedSector {
  RenderSolidColor(this.backgroundColor, {
    this.desiredDeltaRadius: double.INFINITY,
    this.desiredDeltaTheta: kTwoPi
  }) : super(new BoxDecoration(backgroundColor: backgroundColor));

  double desiredDeltaRadius;
  double desiredDeltaTheta;
  final Color backgroundColor;

  @override
  SectorDimensions getIntrinsicDimensions(SectorConstraints constraints, double radius) {
    return new SectorDimensions.withConstraints(constraints, deltaTheta: desiredDeltaTheta);
  }

  @override
  void performLayout() {
    deltaRadius = constraints.constrainDeltaRadius(desiredDeltaRadius);
    deltaTheta = constraints.constrainDeltaTheta(desiredDeltaTheta);
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) {
      decoration = const BoxDecoration(backgroundColor: const Color(0xFFFF0000));
    } else if (event is PointerUpEvent) {
      decoration = new BoxDecoration(backgroundColor: backgroundColor);
    }
  }
}
