// Copyright (c) 2015-2017 Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#ifndef Lumen_Constants_h
#define Lumen_Constants_h

#define MENU_SYMBOL (@"\u262f")
#define STOP (@"Stop")
#define START (@"Start")

#define TELEMETRY_URL (@"https://telemetry.anish.io/api/v1/submit")
#define TELEMETRY_IDENTIFIER (@"lumen-boot")
#define TELEMETRY_RETRIES 5
#define TELEMETRY_RETRY_DELAY 15 // seconds
#define TELEMETRY_SALT (@"com.anishathalye.lumen")
#define TELEMETRY_INTERVAL (1 * 24 * 60 * 60) // seconds

#define DEFAULTS_CALIBRATION_POINTS (@"calibrationPoints")

#define TICK_INTERVAL (0.5) // seconds
#define MIN_X_SPACING (10.0) // absolute difference in L* coordinate
#define CHANGE_NOTICE (0.01) // difference in screen brightness level
#define DEFAULT_BRIGHTNESS (0.5)

static NSString * const IGNORE_LIST_CHANGED_NOTIFICATION = @"notification.ignore-list.changed";
static NSString * const IGNORE_LIST_USER_DEFAULTS_KEY = @"defaults.ignore-list";

#endif
