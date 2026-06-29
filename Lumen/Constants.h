// Copyright (c) Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#ifndef Lumen_Constants_h
#define Lumen_Constants_h

#define STOP (@"Stop")
#define START (@"Start")

#define TELEMETRY_URL (@"https://telemetry.anish.io/api/v1/submit")
#define TELEMETRY_IDENTIFIER (@"lumen-v1")
#define TELEMETRY_RETRIES 5
#define TELEMETRY_RETRY_DELAY 15 // seconds
#define TELEMETRY_SALT (@"com.anishathalye.lumen")
#define TELEMETRY_INTERVAL (1 * 24 * 60 * 60) // seconds

#define DEFAULTS_CALIBRATION_POINTS (@"calibrationPoints")
#define DEFAULTS_IGNORE_LIST (@"ignoreList")

#define NOTIFICATION_IGNORE_LIST_CHANGED (@"notification.ignoreListChanged")

#define LINEAR_SUBSAMPLE (16)

/*
 Brightness control tuning
 -------------------------
 The control loop uses:
   1) a lightness target predicted by the model
   2) a bounded step toward that target each tick
   3) easing so motion slows as we approach the target

 Effective max per-tick step:
   BRIGHTNESS_SMOOTHING_RATE * BRIGHTNESS_SMOOTHING_INTERVAL

 Effective min per-tick step near target (before snap):
   BRIGHTNESS_SMOOTHING_RATE * BRIGHTNESS_EASING_MIN_FACTOR * BRIGHTNESS_SMOOTHING_INTERVAL
 */
#define FRAME_RATE (60) // int, fps
#define DEBOUNCE_DELAY (1) // float, seconds
#define MIN_X_SPACING (10.0) // absolute difference in L* coordinate
#define CHANGE_NOTICE (0.01) // difference in screen brightness level
#define BRIGHTNESS_SMOOTHING_RATE (0.859375) // brightness units per second
#define BRIGHTNESS_SMOOTHING_INTERVAL (1.0 / FRAME_RATE) // seconds
#define BRIGHTNESS_SNAP_THRESHOLD (0.002) // snap to target when this close
#define BRIGHTNESS_EASING_DISTANCE (0.45) // distance from target at which full speed is reached
#define BRIGHTNESS_EASING_MIN_FACTOR (0.08) // minimum speed fraction near the target
// Ignore short post-write hardware settling so auto writes are not learned as manual intent.
#define PROGRAMMATIC_BRIGHTNESS_SETTLE_WINDOW (0.20) // seconds
#define DEFAULT_BRIGHTNESS (0.5)

#endif
