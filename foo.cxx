#include <stdio.h>
#include <stdlib.h>

#include "support.h"
#include "support.cxx"

// Determine current platform
#ifdef _WIN32
#define PIXSCRIBE_USE_WIN32
#endif


// Various architecture-specific features
#ifdef PIXSCRIBE_USE_WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <io.h>
#include <sys/types.h>
#include <sys/stat.h>
#ifndef S_ISDIR
#define S_ISDIR(m)	((m)&_S_IFDIR)
#endif

int geteuid () { return 0; }
int getegid () { return 0; }
#else
#ifdef PIXSCRIBE_USE_VMS
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unixlib.h>	/* geteuid() getegid() and others */
#else /* POSIX */
#ifdef PIXSCRIBE_USE_OSFCN
#include <osfcn.h>
#endif
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <dirent.h>
#endif
#endif


static void pixscribe_split_filename (
    const char * fname,
    PixScribeString &dir,
    PixScribeString &base,
    PixScribeString &ext
    )
{
    const char *dir_end, *fn_end;

    dir = base = ext = 0;
    if ( !fname || !*fname ) return;

#ifdef PIXSCRIBE_USE_VMS
    dir_end = strrchr (fname, ']');    /* directory */
    if (!dir_end) dir_end = strrchr (fname, ':'); /* device */
#else
#ifdef PIXSCRIBE_USE_WIN32
    /* look for dos, unix style and bare drives */
    dir_end = strrchr (fname, '\\'); 
    if (!dir_end) dir_end = strrchr (fname, '/'); 
    if (!dir_end) dir_end = strrchr (fname, ':'); 
#else
    dir_end = strrchr (fname, '/'); 
#endif
#endif
    if (dir_end) {
	dir.ncopy (fname, (dir_end - fname) + 1);
    }
    
    /* if path, bypass delimiter */
    dir_end = (dir_end? dir_end+1: fname);

    /* look for file extension */
    fn_end = strrchr (dir_end, '.'); 

    if (fn_end) 
	ext.copy (fn_end + 1); /* save extension */
    else 
	fn_end = fname+strlen(fname); /* no ext */
	
    if (fn_end != dir_end) {
	base.ncopy (dir_end, fn_end - dir_end);
    }
}

#define NEXT_ARG(i,argc,argv) ((i<argc)? argv[i++]: 0)

int main (int argc, char ** argv)
{
    int i=1;
    char * arg;

    PixScribeString dir;
    PixScribeString base;
    PixScribeString ext;

    /* must have at least one arg */
    if (argc < 2) return 1;

    /* get remaining keyword arguments */
    while (arg = NEXT_ARG(i,argc,argv))
    {
	pixscribe_split_filename (arg, dir, base, ext);

	printf ("in -> %s\n", arg);
	printf (" DIR = [%s]\n", (!dir? "<NONE>": dir.ro()));
	printf (" BASE = [%s]\n", (!base? "<NONE>": base.ro()));
	printf (" EXT = [%s]\n", (!ext? "<NONE>": ext.ro()));

    }
    return 0;
}


