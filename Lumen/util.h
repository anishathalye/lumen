//
//  util.h
//  Lumen
//
//  Created by Anish Athalye on 4/10/15.
//  Copyright (c) 2015 Anish Athalye. All rights reserved.
//

#ifndef __Lumen__util__
#define __Lumen__util__

double linear_interpolate(double x0, double y0, double x1, double y1, double xq);

double clip(double value, double low, double high);

double srgb_to_brightness(double red, double green, double blue);

#endif /* defined(__Lumen__util__) */
