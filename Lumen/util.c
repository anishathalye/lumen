// Copyright (c) 2015-2016 Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#include "util.h"
#include <math.h>

double linear_interpolate(double x0, double y0, double x1, double y1, double xq)
{
    double dydx = (y1 - y0) / (x1 - x0);
    double yq = y0 + dydx * (xq - x0);
    return yq;
}

double clip(double value, double low, double high)
{
    return (value < low) ? (low) : (value > high ? high : value);
}

double srgb_to_lightness(double red, double green, double blue)
{
    double r = red / 255.0, g = green / 255.0, b = blue / 255.0;
    double y;

    r = (r > 0.04045) ? pow((r + 0.055) / 1.055, 2.4) : r / 12.92;
    g = (g > 0.04045) ? pow((g + 0.055) / 1.055, 2.4) : g / 12.92;
    b = (b > 0.04045) ? pow((b + 0.055) / 1.055, 2.4) : b / 12.92;

    y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.00000;

    y = (y > 0.008856) ? pow(y, 1.0/3.0) : (7.787 * y) + 16.0/116.0;

    double lab_l = (116 * y) - 16;

    return lab_l;
}