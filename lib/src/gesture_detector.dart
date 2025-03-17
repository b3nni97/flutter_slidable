import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';

// INTERNAL USE
// ignore_for_file: public_member_api_docs

class SlidableGestureDetector extends StatefulWidget {
  const SlidableGestureDetector({
    Key? key,
    this.enabled = true,
    required this.controller,
    required this.direction,
    required this.child,
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableRightToLeftRestriction = false,
  }) : super(key: key);

  final SlidableController controller;
  final Widget child;
  final Axis direction;
  final bool enabled;

  /// Wether or not the Gesture Detector will only accept right to left
  /// gestures. This will allow parent Gesture Detectors to accept the
  /// Horizontal Gestures, which would be otherwise blocked by this detector.
  /// This will only work for Axis.horizontal.
  final bool enableRightToLeftRestriction;

  /// Determines the way that drag start behavior is handled.
  ///
  /// If set to [DragStartBehavior.start], the drag gesture used to dismiss a
  /// dismissible will begin upon the detection of a drag gesture. If set to
  /// [DragStartBehavior.down] it will begin when a down event is first detected.
  ///
  /// In general, setting this to [DragStartBehavior.start] will make drag
  /// animation smoother and setting it to [DragStartBehavior.down] will make
  /// drag behavior feel slightly more reactive.
  ///
  /// By default, the drag start behavior is [DragStartBehavior.start].
  ///
  /// See also:
  ///
  ///  * [DragGestureRecognizer.dragStartBehavior], which gives an example for the different behaviors.
  final DragStartBehavior dragStartBehavior;

  @override
  _SlidableGestureDetectorState createState() =>
      _SlidableGestureDetectorState();
}

class _SlidableGestureDetectorState extends State<SlidableGestureDetector> {
  double dragExtent = 0;
  late Offset startPosition;
  late Offset lastPosition;

  bool get directionIsXAxis {
    return widget.direction == Axis.horizontal;
  }

  @override
  Widget build(BuildContext context) {
    final canDragHorizontally = directionIsXAxis && widget.enabled;
    final canDragVertically = !directionIsXAxis && widget.enabled;

    if (canDragHorizontally && widget.enableRightToLeftRestriction) {
      return RawGestureDetector(
        gestures: {
          OnlyRightToLeftSlidableDragRecognizer:
              GestureRecognizerFactoryWithHandlers<
                  OnlyRightToLeftSlidableDragRecognizer>(
            () => OnlyRightToLeftSlidableDragRecognizer(
                controller: widget.controller),
            (OnlyRightToLeftSlidableDragRecognizer instance) {
              instance
                ..onStart = handleDragStart
                ..onUpdate = handleDragUpdate
                ..onEnd = handleDragEnd
                ..dragStartBehavior = widget.dragStartBehavior;
            },
          )
        },
        behavior: HitTestBehavior.opaque,
        child: widget.child,
      );
    }

    return GestureDetector(
      onHorizontalDragStart: canDragHorizontally ? handleDragStart : null,
      onHorizontalDragUpdate: canDragHorizontally ? handleDragUpdate : null,
      onHorizontalDragEnd: canDragHorizontally ? handleDragEnd : null,
      onVerticalDragStart: canDragVertically ? handleDragStart : null,
      onVerticalDragUpdate: canDragVertically ? handleDragUpdate : null,
      onVerticalDragEnd: canDragVertically ? handleDragEnd : null,
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: widget.dragStartBehavior,
      child: widget.child,
    );
  }

  double get overallDragAxisExtent {
    final Size? size = context.size;
    return directionIsXAxis ? size!.width : size!.height;
  }

  void handleDragStart(DragStartDetails details) {
    startPosition = details.localPosition;
    lastPosition = startPosition;
    dragExtent = dragExtent.sign *
        overallDragAxisExtent *
        widget.controller.ratio *
        widget.controller.direction.value;
  }

  void handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta!;
    dragExtent += delta;
    lastPosition = details.localPosition;
    widget.controller.ratio = dragExtent / overallDragAxisExtent;
  }

  void handleDragEnd(DragEndDetails details) {
    final delta = lastPosition - startPosition;
    final primaryDelta = directionIsXAxis ? delta.dx : delta.dy;
    final gestureDirection =
        primaryDelta >= 0 ? GestureDirection.opening : GestureDirection.closing;

    widget.controller.dispatchEndGesture(
      details.primaryVelocity,
      gestureDirection,
    );
  }
}

/// A specialized [HorizontalDragGestureRecognizer] that only accepts
/// right-to-left drags unless the Slidable is already open.
///
/// - If the Slidable is closed (controller.ratio == 0.0), any horizontal
///   movement to the right (dx > 0) will be rejected immediately, so that
///   parent widgets (e.g., a TabView) can handle that gesture.
/// - If the Slidable is partially or fully open (controller.ratio != 0.0),
///   this recognizer does not reject rightward movement, allowing the user
///   to swipe back to close the Slidable.
class OnlyRightToLeftSlidableDragRecognizer
    extends HorizontalDragGestureRecognizer {
  OnlyRightToLeftSlidableDragRecognizer({
    required this.controller,
    Object? debugOwner,
  }) : super(debugOwner: debugOwner);

  final SlidableController controller;

  bool _hasDirectionBeenDecided = false;

  @override
  void addPointer(PointerDownEvent event) {
    _hasDirectionBeenDecided = false;
    super.addPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (!_hasDirectionBeenDecided && event is PointerMoveEvent) {
      final bool isSlidableClosed = (controller.ratio == 0.0);
      final double dx = event.delta.dx;

      // If the Slidable is closed and the user swipes to the right (dx > 0),
      // reject immediately so that parent widgets can detect the gesture.
      if (isSlidableClosed && dx > 0) {
        stopTrackingPointer(event.pointer);
        resolve(GestureDisposition.rejected);
        return;
      }

      // Otherwise, let the built-in logic handle acceptance.
      _hasDirectionBeenDecided = true;
    }

    // Pass all subsequent events to the base class (horizontal drag logic).
    super.handleEvent(event);
  }
}
