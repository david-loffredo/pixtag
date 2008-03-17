/* $RCSfile$
 * $Revision$ $Date$
 * Auth: David Loffredo (dave@dave.com)
 * 
 * PixScribe Photo Annotation Tools
 * Copyright (c) 2003-2008 by David Loffredo
 * All Rights Reserved
 * 
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "pixscribe.h"
#include "pixstruct.h"

// use rather than argv[0] for clarity
#define EXEC_NAME	"pix" 
#define NEXT_ARG(i,argc,argv) ((i<argc)? argv[i++]: 0)

// The subcommands are called with argv+1 rather than argv, so that
// they can be written as if they were just standalone command line
// execs.
//
static int cat_main (int argc, char ** argv);
static int update_main (int argc, char ** argv);
static int get_main (int argc, char ** argv);

static const char * main_usage = 
"Usage: %s <cmd> [options]\n"
"\n"
" Work with descriptions of digital photos in *.pixscribe xml\n"
" files and do some other useful tasks with picture files.  The\n"
" following commands are available:\n"
"\n"
"  cat\t - concatenate pixscript files.\n"
"  update - update pixscript file against current directory.\n"
"  get - print image description.\n"
"  mv - move image description to new name (does not move file).\n"
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
    if (!strcmp (cmd, "cat")) 		return cat_main (argc-1, argv+1);
    if (!strcmp (cmd, "update")) 	return update_main (argc-1, argv+1);
    if (!strcmp (cmd, "get")) 		return get_main (argc-1, argv+1);
    //if (!strcmp (cmd, "mv")) 		return mv_main (argc-1, argv+1);
    if (!strcmp (cmd, "help")) 		usage (EXEC_NAME);

    fprintf (stderr, "%s: Unknown command %s\n", EXEC_NAME, cmd);
    return 1;
}



// ======================================================================
// CAT SUBCOMMAND 
// ======================================================================

static const char * cat_usage = 
"Usage: pix cat [options] <pixfiles> ...\n"
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





// ======================================================================
// UPDATE SUBCOMMAND 
// ======================================================================

static const char * update_usage = 
"Usage: pix update [options] <pixfile> [<dir>]\n"
"\n"
" Update a pixscript file against the contents of a directory.\n"
" By default, the current directory is used, but a different dir\n"
" may be specified on the command line.  Options are:\n"
"\n"
" -help\t\t - print this help message. \n"
" -desc <msg>\t - Use description <msg> for all new entries.\n"
" -event <id>\t - Add an event <id> to all new entries.\n"
" -n\t\t - Print report of changes, but do not update file.\n"
" -o <file>\t - Save the updated file as <file>.  By default the\n"
" \t\t   results are saved to the same file.\n"
"\n";

static int update_main (int argc, char ** argv)
{
    int i=1;
    char * arg;
    char * outfile = 0;  // stdout by default
    char * desc = 0;
    char * event = 0;
    int scanonly = 0;
    
    /* must have at least one arg */
    if (argc < 2) { 
	fprintf (stderr, update_usage);
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
	    fprintf (stderr, update_usage);
	    return (1);
	}
	else if (!strcmp (arg, "-desc")) 
	{	
	    desc = NEXT_ARG(i,argc,argv);
	}
	else if (!strcmp (arg, "-event")) 
	{	
	    event = NEXT_ARG(i,argc,argv);
	}
	else if (!strcmp (arg, "-n"))
	{ 
	    scanonly = 1;
	}
	else break;
    }

    if (!arg) { 
	// we could go look for one
	fprintf (stderr, update_usage);
	return (1);
    }

    if (!outfile) outfile = arg;



    PixScribeDB * db = pixscribe_new_db();
    if (pixscribe_read_xml(db, arg) > 0) 
    {
	// Returns 0 if ok and -1 if no file.  If > 0 then XML errors
	// present.  Do not continue if errors in file since that does
	// not give any chance to correct it.
	fprintf (stderr, "%s: errors in file, update cancelled\n",
		 (arg? arg: "<no file>"));
	return 1;
    }

    pixscribe_set_photo_desc (
	pixscribe_default_photo(db), desc
	);

    pixscribe_add_photo_event (
	pixscribe_default_photo(db), 
	pixscribe_make_event(db, event)
	);

    pixscribe_update_from_directory (db, NEXT_ARG(i,argc,argv));
    pixscribe_report (db);

    if (!scanonly) {
	fprintf (stderr, "%s: saving updated file\n", 
		 (outfile? outfile: "<no file>"));

	pixscribe_write_xml (db, outfile);
    }

    pixscribe_release_db (db);
    return 0;
}



// ======================================================================
// MV SUBCOMMAND 
// ======================================================================

static const char * mv_usage = 
"Usage: pix update [options] <pixfile> [<dir>]\n"
"\n"
" Move the image description in a pixscript file from one name\n"
" to another.  This does not move the corresponding image file.\n"
" Options are:\n"
"\n"
" -help\t\t - print this help message. \n"
" -n\t\t - Print report of changes, but do not update file.\n"
" -o <file>\t - Save the updated file as <file>.  By default the\n"
" \t\t   results are saved to the same file.\n"
"\n";

static int mv_main (int argc, char ** argv)
{
    int i=1;
    char * arg;
    char * outfile = 0;  // stdout by default
    int scanonly = 0;
    
    /* must have at least one arg */
    if (argc < 2) { 
	fprintf (stderr, update_usage);
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
	    fprintf (stderr, update_usage);
	    return (1);
	}
	else if (!strcmp (arg, "-n"))
	{ 
	    scanonly = 1;
	}
	else break;
    }

    
    if (!arg) { 
	// we could go look for one
	fprintf (stderr, update_usage);
	return (1);
    }

    if (!outfile) outfile = arg;



    PixScribeDB * db = pixscribe_new_db();
    if (pixscribe_read_xml(db, arg) > 0) 
    {
	// Returns 0 if ok and -1 if no file.  If > 0 then XML errors
	// present.  Do not continue if errors in file since that does
	// not give any chance to correct it.
	fprintf (stderr, "%s: errors in file, update cancelled\n",
		 (arg? arg: "<no file>"));
	return 1;
    }

    if (!scanonly) {
	fprintf (stderr, "%s: saving updated file\n", 
		 (outfile? outfile: "<no file>"));

	pixscribe_write_xml (db, outfile);
    }

    pixscribe_release_db (db);
    return 0;
}





// ======================================================================
// GET SUBCOMMAND 
// ======================================================================

static const char * get_usage = 
"Usage: pix get [options] <pixfile> [<photo> ... ]\n"
"\n"
" Generate html from a pixscript file.\n"
"\n"
" -help\t\t - print this help message. \n"
"\n";

static int get_main (int argc, char ** argv)
{
    int i=1;
    char * arg;
    char * outfn = 0;
    char * tagfn = 0;
    char * photofn = 0; 
    
    /* must have at least one arg */
    if (argc < 3) { 
	fprintf (stderr, get_usage);
	return (1);
    }

    /* get remaining keyword arguments */
    while (arg = NEXT_ARG(i,argc,argv))
    {
	/* command line options */
	if (!strcmp (arg, "-o")) 
	{	
	    outfn = NEXT_ARG(i,argc,argv);
 	}
	else if (!strcmp (arg, "-h") ||
 		 !strcmp (arg, "-help")) 
 	{ 
 	    fprintf (stderr, get_usage);
 	    return (1);
 	}
 	else break;
    }

    if (!arg) { 
	fprintf (stderr, "No tag file specified!\n\n");	  
	fprintf (stderr, update_usage);	  
	return (1);
    }


    PixScribeDB * db = pixscribe_new_db();
    if (pixscribe_read_xml(db, arg) > 0) 
    {
	fprintf (stderr, "%s: warning: errors in tag file\n",
		 (arg? arg: "<no file>"));
    }

    while (arg = NEXT_ARG(i,argc,argv)) {
	PixScribePhoto * p = db-> find_photo (arg);
	unsigned i,sz;

	if (!p) {
	    fprintf (stderr, "%s: photo description not found\n", arg);
	    continue;
	}
	const char * msg = pixscribe_get_photo_desc (p);

	if (msg) {
	    fputs (msg, stdout);
	    fputs ("\n", stdout);
	}
	for (i=0, sz=p->events.size(); i<sz; i++) {
	    const char * msg = pixscribe_get_event_desc (
		(PixScribeEvent*) p->events[i]
		);
	    if (msg) {
		fputs ("\n", stdout);
		fputs (msg, stdout);
		fputs ("\n", stdout);
	    }
	}
    }
    pixscribe_release_db (db);
    return 0;
}

