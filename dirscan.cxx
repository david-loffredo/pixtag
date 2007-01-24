/* $RCSfile$
 * $Revision$ $Date$
 * Auth: David Loffredo (dave@dave.com)
 * 
 * PixScribe Photo Annotation Tools
 * Copyright (c) 2003-2007 by David Loffredo
 * All Rights Reserved
 * 
 */

#include <stdio.h>
#include <stdlib.h>

#include "pixscribe.h"
#include "pixstruct.h"

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
#else
#ifdef PIXSCRIBE_USE_VMS
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unixlib.h>	/* geteuid() getegid() and others */
#else /* POSIX */
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


static PixScribeString pixscribe_cat_filename (
    const char * dir,
    const char * base,
    const char * ext
    )
{
    PixScribeString result;
    result.resize (
	(dir? strlen (dir): 0) +
	(base? strlen (base): 0) +
	(ext? strlen (ext): 0) + 3
	);

    if (dir && *dir) {
	// add delimiter if not already present
	result = dir;
	char lc = dir[strlen(dir)-1];
#ifdef PIXSCRIBE_USE_VMS
	// should already have [] delimeters
#else
#ifdef PIXSCRIBE_USE_WIN32
	if ((lc != '\\') && (lc != '/') && (lc != ':') )
	    result += "\\";
#else
	if ((lc != '/')) result += "/";
#endif
#endif
    }
    
    if (base && *base) {
	result += base;
    }
    
    if (ext && *ext) {
	if (ext[0] != '.') result += ".";
	result += ext;
    }
    return result;
}



int pixscribe_is_photo_file (
    const char * fn
    )
{
    /* eventually we can make the extensions user configurable, but
     * for now, just hard code jpgs and gifs.
     */
    PixScribeString dir;
    PixScribeString base;
    PixScribeString ext;
    pixscribe_split_filename (fn, dir, base, ext);

    return (ext && 
	    (!strcasecmp(ext, "jpg") ||
	     !strcasecmp(ext, "jpeg") ||
	     !strcasecmp(ext, "gif"))
	);
}





static int pixscribe_dir_exists (const char * dir_name) 
{
#ifdef PIXSCRIBE_USE_VMS
    return 1;	/* replace with the real thing */
#else
#ifdef PIXSCRIBE_USE_WIN32
    /* non-posix, hidden using ansi-compliant underscore */
    struct _stat buf;
    return (_stat(dir_name, &buf) == 0) && (buf.st_mode & _S_IFDIR);
#else
    /* proper posix formation */
    struct stat buf;
    return (stat(dir_name, &buf) == 0) && (S_ISDIR (buf.st_mode) != 0);
#endif
#endif
}



int pixscribe_update_from_directory (
    PixScribeDB * db, 
    const char * dirname
    )
{
    /* Mark everything as missing, then mark them as OK when seen. */

    unsigned i,sz;

    for (i=0,sz=db->photos.size(); i<sz; i++) {
	PixScribePhoto * p = (PixScribePhoto*) db->photos[i];
	p-> status = PIXSCRIBE_PHOTO_MISSING;
    }

#ifdef PIXSCRIBE_USE_VMS
    /* replace with the real thing */
#else
#ifdef PIXSCRIBE_USE_WIN32
    PixScribeString 	dir_obj (
	pixscribe_cat_filename (dirname, "*", "*")
	);

    WIN32_FIND_DATA buf;
    HANDLE hdl = FindFirstFile (dir_obj.ro(), &buf); 

    if (hdl == INVALID_HANDLE_VALUE) {
	return 1;  // bad dir or no files
    }

    do {
	// ignore things that are not regular files
	if (buf.dwFileAttributes &
	    (FILE_ATTRIBUTE_DIRECTORY |
	     FILE_ATTRIBUTE_SYSTEM |
	     FILE_ATTRIBUTE_HIDDEN))
	    continue;

	if (!pixscribe_is_photo_file (buf.cFileName))
	    continue;

	PixScribePhoto * p = db-> find_photo(buf.cFileName);
	if (p) {
	    p-> status = PIXSCRIBE_PHOTO_OK;
	}
	else {
	    /* check whether it matches the image pattern */
	    p = new PixScribePhoto(db->dflt_photo);
	    p-> filename = buf.cFileName;
	    p-> status = PIXSCRIBE_PHOTO_NEW;
	    db-> photos.append (p);
	}

    } while (FindNextFile (hdl, &buf));
    FindClose (hdl);

#else
    DIR * dirp;
    struct dirent * dp;

    PixScribeString 	dir_obj;
    RoseHandle 		my_proto;

    dir_obj = rose_expand_path (dir_name, NULL, NULL);
    dirp = opendir (dir_obj);
    if (!dirp) { 
	//ROSE.report (ROSE_EC_NO_DIR, dir_name);
    }
    else {
	for ( dp = readdir (dirp); dp; dp = readdir (dirp) ) {
	    if (rose_file_matches (dp->d_name, proto, &my_proto) 
		&& !files->find (my_proto.name()) ) { 
		/* new handle */
		RoseHandle * temp = new RoseHandle;
		temp-> NP_dir = dir_obj;
		temp-> NP_name = my_proto.NP_name;
		temp-> NP_ext = my_proto.NP_ext;
		files-> put (my_proto.NP_name, temp);
	    }
	}
	closedir (dirp);
    }
#endif
#endif
    return 0;  
}
