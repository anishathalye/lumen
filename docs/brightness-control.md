# Brightness Control Design Notes

This document explains the current brightness-control behavior in `Lumen/BrightnessController.m` and the tuning constants in `Lumen/Constants.h`.

## Goals

- Adjust brightness smoothly instead of jumping.
- Preserve user intent by learning from manual brightness changes.
- Avoid control-loop stalls when screen-capture callbacks are sparse.
- Keep tuning predictable with a small set of constants.

## High-level flow

1. Screen samples arrive via `SCStream` and are converted to a single `lightness` value.
2. The latest lightness sample is cached.
3. A timer-driven control loop runs at `BRIGHTNESS_SMOOTHING_INTERVAL`.
4. Each control tick:
   - Detects manual brightness changes from hardware readback.
   - Updates the model when manual intent is confirmed.
   - Predicts target brightness from current lightness.
   - Applies one eased step toward the target.

## Why timer-driven control

Brightness updates are not applied directly from frame callbacks. Instead, callbacks only refresh `latestLightness`, while a timer applies brightness steps.

This prevents stalls where dimming appears to resume only after user activity (for example, pointer/menu interactions) because the control loop no longer depends on callback cadence.

## Manual vs programmatic writes

Manual intent is inferred by comparing hardware readback (`getBrightness`) against the last known setpoint. To avoid learning from our own writes, short post-write settling is ignored for `PROGRAMMATIC_BRIGHTNESS_SETTLE_WINDOW`.

This separation is critical:

- Without it, Lumen can accidentally "learn itself."
- With too much filtering, true manual changes can be missed.

## Smoothing and easing model

At each tick:

- `delta = targetBrightness - lastAssigned`
- If `abs(delta) <= BRIGHTNESS_SNAP_THRESHOLD`, snap to target.
- Otherwise compute an eased speed factor:
  - Normalize distance by `BRIGHTNESS_EASING_DISTANCE`.
  - Apply smoothstep easing (`x*x*(3-2*x)`).
  - Blend with `BRIGHTNESS_EASING_MIN_FACTOR` near target.
- Apply bounded step:
  - `maxStep = BRIGHTNESS_SMOOTHING_RATE * speedFactor * elapsed`
  - `step = sign(delta) * min(abs(delta), maxStep)`

This yields:

- Fast movement when far from target.
- Soft tail as target is approached.

## Current tuning values

From `Lumen/Constants.h`:

- `FRAME_RATE = 60`
- `BRIGHTNESS_SMOOTHING_RATE = 0.859375`
- `BRIGHTNESS_EASING_DISTANCE = 0.45`
- `BRIGHTNESS_EASING_MIN_FACTOR = 0.08`
- `BRIGHTNESS_SNAP_THRESHOLD = 0.002`
- `PROGRAMMATIC_BRIGHTNESS_SETTLE_WINDOW = 0.20`

## Practical tuning guidance

- Want overall faster/slower transitions:
  - Increase/decrease `BRIGHTNESS_SMOOTHING_RATE`.
- Want softer/harder tail:
  - Decrease/increase `BRIGHTNESS_EASING_MIN_FACTOR`.
- Want easing to begin earlier/later:
  - Increase/decrease `BRIGHTNESS_EASING_DISTANCE`.
- Want less lingering near target:
  - Increase `BRIGHTNESS_SNAP_THRESHOLD`.

## Validation checklist

- Build succeeds with `xcodebuild`.
- `Screen capture started successfully` appears in logs.
- Switching between bright/dark content transitions without needing pointer/menu activity.
- Manual brightness adjustments are learned and reused for similar lightness.
