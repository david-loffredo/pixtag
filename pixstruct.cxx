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

#ifdef _WIN32
#define strcasecmp _stricmp
#endif

int pixscribe_event_cmp (const void* a, const void* b)
{
    /* compare events by id, but watch for null */
    PixScribeEvent * ea = (*(PixScribeEvent **) a);
    PixScribeEvent * eb = (*(PixScribeEvent **) b);
    return strcmp ((ea? ea-> id: ""), (eb? eb-> id: ""));
} 	

int pixscribe_photo_cmp (const void* a, const void* b)
{
    /* compare events by id, but watch for null */
    /* compare case insensitive, since some filesystems are */
    PixScribePhoto * ea = (*(PixScribePhoto **) a);
    PixScribePhoto * eb = (*(PixScribePhoto **) b);
    return strcasecmp ((ea? ea-> filename: ""), (eb? eb-> filename: ""));
} 	

void PixScribeDB::sort_events()
{
    /* need to use [] operator because it returns an lvalue, whereas
     * the get() method does not (void*& vs. void*)
     */
    if (events.size())
	qsort ((void *) &(events[0]), events.size(), sizeof (void *), 
	       &pixscribe_event_cmp);
}


void PixScribeDB::sort_photos()
{
    if (photos.size())
	qsort ((void *) &(photos[0]), photos.size(), sizeof (void *), 
	       &pixscribe_photo_cmp);
}




int pixscribe_report (
    PixScribeDB * db
    )
{
    unsigned i,sz;
    const char * last_fn = 0;

    db-> sort_photos();

    for (i=0,sz=db->photos.size(); i<sz; i++) {
	PixScribePhoto * p = (PixScribePhoto*) db->photos[i];
	const char * fn = p-> filename.ro();
	if (last_fn && !strcasecmp (fn, last_fn)) {
	    printf ("%s: DUPLICATE\n", fn);
	}
	last_fn = fn;

	if (p-> status == PIXSCRIBE_PHOTO_NEW) {
	    printf ("%s: NEW\n", fn);
	}
	if (p-> status == PIXSCRIBE_PHOTO_MISSING) {
	    printf ("%s: MISSING\n", fn);
	}
    }
    return 0;
}