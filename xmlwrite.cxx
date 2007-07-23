/* $RCSfile$
 * $Revision$ $Date$
 * Auth: David Loffredo (dave@dave.com)
 * 
 * PixScribe Photo Annotation Tools
 * Copyright (c) 2003-2007 by David Loffredo
 * All Rights Reserved
 * 
 */

//include <ctype.h>
#include <stdio.h>
#include <stdlib.h>

#include "pixscribe.h"
#include "pixstruct.h"

// Keep static for the moment
static int pixscribe_write_photo_xml (PixScribePhoto *, FILE * f = 0);
static int pixscribe_write_event_xml (PixScribeEvent *, FILE * f = 0);


static void fputs_cdata(const char * s, FILE * f)
{
    char c;
    if (!s || !f) return;

    while(c = *s++) {
	switch (c) {
	case '&':   fputs("&amp;", f);	    break;
	case '<':   fputs("&lt;", f);	    break;
	case '>':   fputs("&gt;", f);	    break;
	default:
	    if (c & 0x80) 
		fprintf (f, "&#x%02x;", c & 0xff);
	    else 
		putc (c, f);

// 	    if (c > 0 && c < 0x20) 
// 		fprintf (fd, "&#xf01%02x;", c);
	}
    }
}

static void fputs_attval(const char * s, FILE * f)
{
    char c;
    if (!s || !f) return;

    while(c = *s++) {
	switch (c) {
	case '"':   fputs("&quot;", f);	    break;
	case '&':   fputs("&amp;", f);	    break;
	case '<':   fputs("&lt;", f);	    break;
	case '>':   fputs("&gt;", f);	    break;
	default:
	    if (c & 0x80) 
		fprintf (f, "&#x%02x;", c & 0xff);
	    else 
		putc (c, f);
	}
    }
}

int pixscribe_write_xml (
    PixScribeDB * db, 
    const char * fn
    )
{
    unsigned i,sz;

//     // need to rename existing file to a backup
//     errno = 0;
//     if ( ((::remove(to)) && (errno != ENOENT)) || 
// 	 (rename (from,to)))
//     {
// 	ROSE.warning ("Unable to rename %s to %s", from, to);
// 	return 1;
//     }

    FILE * file = stdout;
    if (fn && *fn) 
	file = fopen (fn, "w");

    if (!file) return 1;

    db-> sort_events();
    db-> sort_photos();

    fputs ("<pixscribe>\n\n", file);
    for (i=0,sz=db->events.size(); i<sz; i++) {
	PixScribeEvent * e = (PixScribeEvent*) db->events[i];
	pixscribe_write_event_xml (e, file);
    }

    for (i=0,sz=db->photos.size(); i<sz; i++) {
	PixScribePhoto * p = (PixScribePhoto*) db->photos[i];
	pixscribe_write_photo_xml (p, file);
    }

    fputs ("</pixscribe>\n", file);
    fclose (file);
    return 0;
}


int pixscribe_write_photo_xml (
    PixScribePhoto * p, 
    FILE * file
    )
{
    unsigned i,sz;

    if (!p) return 1;
    if (!file) file = stdout;

    if (p-> status == PIXSCRIBE_PHOTO_MISSING) {
	fputs ("<!-- MISSING PHOTO -->\n", file);
    }

    fputs ("<photo file=\"", file);
    fputs_attval (p->filename, file);
    fputs ("\">\n", file);

    for (i=0,sz=p->events.size(); i<sz; i++) {
	PixScribeEvent * e = (PixScribeEvent*) p->events[i];
	if (e) {
	    fputs (" <event ref=\"", file);
	    fputs_attval (e->id, file);
	    fputs ("\" />\n", file);
	}
    }

    fputs (" <desc>", file);
    if (!p->desc.is_empty())
	fputs_cdata (p->desc, file);
    fputs ("</desc>\n", file);
    fputs ("</photo>\n\n", file);
    return 0;
}


int pixscribe_write_event_xml (
    PixScribeEvent * event, 
    FILE * file
    )
{
    if (!event) return 1;
    if (!file) file = stdout;

    fputs ("<event id=\"", file);
    fputs_attval (event->id, file);
    fputs ("\">\n", file);

    fputs (" <desc>", file);
    if (!event->desc.is_empty())
	fputs_cdata (event->desc, file);
    fputs ("</desc>\n", file);
    fputs ("</event>\n\n", file);
    return 0;
}
