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

// use rather than argv[0] for clarity
#define EXEC_NAME	"pix" 
#define NEXT_ARG(i,argc,argv) ((i<argc)? argv[i++]: 0)

// The subcommands are called with argv+1 rather than argv, so that
// they can be written as if they were just standalone command line
// execs.
//
static int cat_main (int argc, char ** argv);

static const char * main_usage = 
"Usage: %s <cmd> [options]\n"
"\n"
" Work with descriptions of digital photos in *.pixscribe xml\n"
" files and do some other useful tasks with picture files.  The\n"
" following commands are available:\n"
"\n"
"  cat\t - concatenate pixscript files.\n"
"\n"
" For more information on any command, call it with the -help\n"
" option, like \"pix cat -help\"\n"
"\n";

static void usage (const char * name) 
{  
    fprintf (stderr, main_usage, name);
    exit (1);
}

int main (int argc, char ** argv)
{
    int i=1;
    char * cmd = NEXT_ARG(i,argc,argv);

    /* must have at least one arg */
    if (!cmd) usage (EXEC_NAME);

    /* command line options */
    if (!strcmp (cmd, "cat")) {
	return cat_main (argc-1, argv+1);
    }
    else {
	fprintf (stderr, "%s: Unknown command %s\n", EXEC_NAME, cmd);
	return 1;
    }

    return 0;
}



// ======================================================================
// CAT SUBCOMMAND 
// ======================================================================

static const char * cat_usage = 
"Usage: pix cat [options] <files>\n"
"\n"
" Read and concatenate pixscript files.  The tool will warn about\n"
" XML problems and duplicate photo entries.  Options are:\n"
"\n"
" -help\t\t - print this help message. \n"
" -o <file>\t - Save the merged files to <file>.  By default the\n"
" \t\t - results are printed to stdout\n"
"\n";

static int cat_main (int argc, char ** argv)
{
    int i=1;
    char * arg;
    char * outfile = 0;  // stdout by default

    /* must have at least one arg */
    if (argc < 2) { 
	fprintf (stderr, cat_usage);
	return (1);
    }

    /* get remaining keyword arguments */
    while (arg = NEXT_ARG(i,argc,argv))
    {
	/* command line options */
	if (!strcmp (arg, "-o")) 
	{	
	    outfile = NEXT_ARG(i,argc,argv);
	}
	else if (!strcmp (arg, "-h") ||
		 !strcmp (arg, "-help")) 
	{ 
	    fprintf (stderr, cat_usage);
	    return (1);
	}
	else break;
    }

    if (!arg) { 
	fprintf (stderr, cat_usage);
	return (1);
    }

    PixScribeDB * db = pixscribe_new_db();
    while (arg)
    {
	pixscribe_read_xml(db, arg);
	arg = NEXT_ARG(i,argc,argv);
    }

    pixscribe_report (db);
    pixscribe_write_xml (db, outfile);
    pixscribe_release_db (db);
    return 0;
}


