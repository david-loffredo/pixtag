/* $RCSfile$
 * $Revision$ $Date$
 * Auth: David Loffredo (dave@dave.com)
 * 
 * PixScribe Photo Annotation Tools
 * Copyright (c) 2003-2007 by David Loffredo
 * All Rights Reserved
 * 
 * Internal structures used by PixScribe 
 */

#ifndef PIXSTRUCT_H
#define PIXSTRUCT_H

#include "support.h"

#define PIXSCRIBE_PHOTO_OK	0
#define PIXSCRIBE_PHOTO_NEW	1
#define PIXSCRIBE_PHOTO_MISSING	2

struct PixScribePhoto {
    PixScribeString 	filename;
    PixScribeString 	desc;
    PixScribeVector	events;
    
    int status;
    PixScribePhoto() { status = PIXSCRIBE_PHOTO_OK; }
    PixScribePhoto (const PixScribePhoto &other) :
	filename(other.filename), 
	desc(other.desc), 
	events(other.events),
	status(PIXSCRIBE_PHOTO_NEW)
    {}
};

struct PixScribeEvent {
    PixScribeString 	id;
    PixScribeString 	desc;
};


struct PixScribeDB {
    PixScribeVector	photos;
    PixScribeVector	events;

    PixScribePhoto	dflt_photo;

    ~PixScribeDB() {
	unsigned i,sz;
	for (i=0,sz=photos.size(); i<sz; i++) 
	    delete (PixScribePhoto*) photos[i];

	for (i=0,sz=events.size(); i<sz; i++) 
	    delete (PixScribeEvent*) events[i];
    }

    void sort_events();
    void sort_photos();

    PixScribeEvent * find_event (const char * id) {
	unsigned i,sz;
	for (i=0,sz=events.size(); i<sz; i++) {
	    PixScribeEvent * e = (PixScribeEvent*) events[i];
	    if (e && !strcmp (id, e->id)) return e;
	}
	return 0;
    }

    /* eventually use a more sophisticated index */
    PixScribePhoto * find_photo (const char * fn) {
	unsigned i,sz;
	for (i=0,sz=photos.size(); i<sz; i++) {
	    PixScribePhoto * p = (PixScribePhoto*) photos[i];
	    if (p && !strcmp (fn, p->filename)) return p;
	}
	return 0;
    }
};

#endif /* PIXSTRUCT_H */


