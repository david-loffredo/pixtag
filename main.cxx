/* $RCSfile$
 * $Revision$ $Date$
 * Auth: David Loffredo (dave@dave.com)
 * 
 * PixScribe Photo Annotation Tools
 * Copyright (c) 2003-2007 by David Loffredo
 * All Rights Reserved
 * 
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "pixscribe.h"

static void usage (char * name)
{
    fprintf (stderr, "%s: <filename>\n", name);
    fprintf (stderr, "Options:\n");
    fprintf (stderr, "  -refresh: add annotations for new files\n");
    exit (1);
}

#define NEXT_ARG(i,argc,argv) ((i<argc)? argv[i++]: 0)

int main (int argc, char ** argv)
{
    int i=1;
    char * arg;

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
	else break;
    }
    if (!arg) usage(argv[0]);


    PixScribeDB * db = pixscribe_new_db();
    while (arg)
    {
	pixscribe_read_xml(db, arg);
	arg = NEXT_ARG(i,argc,argv);
    }

    pixscribe_update_from_directory (db, ".");

    pixscribe_report (db);
    pixscribe_write_xml (db, 0);
    pixscribe_release_db (db);
    return 0;
}


