//
//  getwinsize.c
//  FirstIOEngine
//
//  Created by Richard McNeal on 11/2/17.
//  Copyright © 2017 Richard McNeal. All rights reserved.
//

#include "getwinsize.h"

int getwinsize()
{
	struct winsize w;
	if (ioctl(0, TIOCGWINSZ, &w) != 0)
		return 72;
	else
		return w.ws_col;
}
