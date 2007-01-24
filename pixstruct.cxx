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
	    fprintf (stderr, "%s: DUPLICATE\n", fn);
	}
	last_fn = fn;

	if (p-> status == PIXSCRIBE_PHOTO_NEW) {
	    fprintf (stderr, "%s: NEW\n", fn);
	}
	if (p-> status == PIXSCRIBE_PHOTO_MISSING) {
	    fprintf (stderr, "%s: MISSING\n", fn);
	}
    }
    return 0;
}


    
PixScribePhoto * pixscribe_default_photo(
    PixScribeDB * db
    )
{
    return &(db-> dflt_photo);
}


char * pixscribe_get_photo_file (PixScribePhoto * p)
{
    return (p? p-> filename.ro(): 0);
}

void pixscribe_set_photo_file (PixScribePhoto * p, const char * s)
{
    if (p) p-> filename = s;
}

char * pixscribe_get_photo_desc (PixScribePhoto * p)
{
    return (p? p-> desc.ro(): 0);
}

void pixscribe_set_photo_desc (PixScribePhoto * p, const char * s)
{
    if (p) p-> desc = s;
}


void pixscribe_add_photo_event (
    PixScribePhoto * p, 
    PixScribeEvent * e
    )
{
    if (p && e) {
	// really should check for duplicates
	p-> events.append (e);
    }
}




char * pixscribe_get_event_id (PixScribeEvent * p)
{
    return (p? p-> id.ro(): 0);
}

void pixscribe_set_event_id (PixScribeEvent * p, const char * s)
{
    if (p) p-> id = s;
}

char * pixscribe_get_event_desc (PixScribeEvent * p)
{
    return (p? p-> desc.ro(): 0);
}

void pixscribe_set_event_desc (PixScribeEvent * p, const char * s)
{
    if (p) p-> desc = s;
}




PixScribeEvent * pixscribe_find_event (
    PixScribeDB * db,
    const char * id
    ) 
{
    return (db? db-> find_event(id): 0);
}


PixScribeEvent * pixscribe_make_event (
    PixScribeDB * db,
    const char * id
    ) 
{
    if (!db || !id || !*id) return 0;

    PixScribeEvent * e = db-> find_event(id);
    if (!e) {
	e = new PixScribeEvent;
	e-> id = id;
	db-> events.append (e);
    }
    return e;
}
