/* $RCSfile$
 * $Revision$ $Date$
 * Auth: Dave Loffredo (loffredo@steptools.com)
 * 
 * Copyright (c) 2003 by Dave Loffredo 
 * All Rights Reserved.
 * 
 * This file is part of the PIXLIB software package
 * 
 * This file may be distributed and/or modified under the terms of 
 * the GNU General Public License version 2 as published by the Free
 * Software Foundation and appearing in the file LICENSE.GPL included
 * with this file.
 * 
 * THIS FILE IS PROVIDED "AS IS" WITH NO WARRANTY OF ANY KIND,
 * INCLUDING THE WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE.
 * 
 * 		----------------------------------------
 * 
 *  The phix program pushes pixtag data into all of the various 
 *  protocols for encoding image file metadata. 
 * 
 */

#include <stdio.h>
#include <string.h>
#include "pixscribe.h"

static void usage (char * name)
{
    fprintf (stderr, "%s: <filename>\n", name);
    fprintf (stderr, "Options:\n");
    fprintf (stderr, "  -units: dump known unit coversions\n");
    exit (1);
}

#define NEXT_ARG(i,argc,argv) ((i<argc)? argv[i++]: 0)

int main (int argc, char ** argv)
{
    int i=1;
    char * arg;
    StixNC stepnc;

    /* must have at least one arg */
    if (argc < 2) usage (argv[0]);

    /* get remaining keyword arguments */
    while (arg = NEXT_ARG(i,argc,argv))
    {
	/* command line options */
	if (!strcmp (arg, "-refresh")) 
	{	
	    // read and refresh a pixtag file against the contents of
	    // a given directory.
	}

    }
    return 0;
}

