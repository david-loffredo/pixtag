/* $RCSfile$
 * $Revision$ $Date$
 * Auth: David Loffredo (dave@dave.com)
 * 
 * PixScribe Photo Annotation Tools
 * Copyright (c) 2003-2007 by David Loffredo
 * All Rights Reserved
 * 
 */

#define BUFF_SIZE 10240
#include <stdio.h>

#define XML_STATIC
#include "expat.h"
#include "pixscribe.h"
#include "pixstruct.h"

/* Element names */
#define PIXTAG_ELEMENT 		"pixtag"
#define PIXSCRIBE_ELEMENT 	"pixscribe"
#define PHOTO_ELEMENT 		"photo"
#define EVENT_ELEMENT 		"event"
#define DESC_ELEMENT 		"desc"

#define STATE_INITIAL 		((int)0)
#define STATE_ERROR 		((int)1)
#define STATE_PIXSCRIPT		((int)2)
#define STATE_EVENT		((int)3)
#define	STATE_EVENT_PROP	((int)4)
#define	STATE_EVENT_REF		((int)5)
#define	STATE_PHOTO		((int)6)
#define	STATE_PHOTO_PROP	((int)7)

static void XMLCALL do_start_tag (void *, const XML_Char *, const XML_Char **);
static void XMLCALL do_end_tag   (void *, const XML_Char *);
static void XMLCALL do_cdata     (void *, const XML_Char *, int len);

struct PixScriptXMLReader {
    XML_Parser 		parser;
    PixScribeString	filename;
    
    PixScribeDB *	db;
    PixScribeEvent *	event;
    PixScribePhoto *	photo;

    PixScribeStack 	state;
    PixScribeString	cdata;

    void push (int s) 	{ state.push ((void*)s); }
    int  pop() 		{ return (int) state.pop(); }
    int  top() 		{ return (int) state.top(); }

    void start_cdata() {
	cdata = 0;
	XML_SetCharacterDataHandler(parser, do_cdata);    
    }

    void end_cdata() {
	XML_SetCharacterDataHandler(parser, 0);
    }


    void error(const char * msg) {
	fprintf (stderr, "%s: line %d: %s\n",
		 filename.ro(), XML_GetCurrentLineNumber(parser), msg
	    );
    }

    PixScriptXMLReader() { parser = 0; db = 0; event=0; photo=0;}
    ~PixScriptXMLReader() {}
};


PixScribeDB * pixscribe_new_db()
{
    return new PixScribeDB;
}

void pixscribe_release_db (PixScribeDB * db)
{
    if (db) delete db;
}


int pixscribe_read_xml (
    PixScribeDB * db, 
    const char * filename
    )
{
    PixScriptXMLReader reader;
    if ( !db || !filename) return 1;

    FILE * file = fopen (filename, "r");
    if ( !file) {
	return 1;  // could not read
    }


    XML_Parser xp = XML_ParserCreateNS(NULL, '|');
    XML_SetUserData(xp, &reader);
    reader.parser = xp;
    reader.db = db;
    reader.filename = filename;

    /* Set callbacks */   
    XML_SetElementHandler(xp, do_start_tag, do_end_tag);
    
    unsigned bytes_read;
    do {
	void * buff = XML_GetBuffer(xp, BUFF_SIZE);
	bytes_read = fread (buff, 1, BUFF_SIZE, file);
	if (XML_ParseBuffer(xp, bytes_read, (bytes_read == 0)) !=
	    XML_STATUS_OK) {
	    
	    reader.error (XML_ErrorString(XML_GetErrorCode(xp)));
	    break;
	}
    } while (bytes_read > 0);

    XML_ParserFree(xp);    
    fclose (file);

    return 0;
}


static PixScribePhoto * get_photo( 
    PixScriptXMLReader * r,
    const XML_Char **atts
    )
{
    PixScribePhoto * p = new PixScribePhoto;

    while (*atts) {
	const XML_Char * att = *atts++;
	const XML_Char * val = *atts++;

	if (!strcmp (att, "file")) {
	    p-> filename = val;
	}
    }
    if (p-> filename.is_empty()) {
	r->error ("photo missing/empty 'file' att");
    }

    r-> db-> photos.append (p);
    return p;
}


static PixScribeEvent * get_event( 
    PixScriptXMLReader * r,
    const XML_Char **atts
    )
{
    PixScribeEvent * e = 0;

    while (*atts) {
	const XML_Char * att = *atts++;
	const XML_Char * val = *atts++;

	/* brand new event */
	if (!e && !strcmp (att, "id")) {
	    e = new PixScribeEvent;
	    e-> id = val;
	    r-> db-> events.append (e);
	}

	/* look for an existing one */
	if (!e && !strcmp (att, "ref")) {
	    e = r-> db-> find_event(val);
	    if (!e) r-> error("reference to unknown event");
	    return e;
	}
    }

    if (!e) {
	if (!e) r-> error("anonymous/undefined event");
    }
    else if (e-> id.is_empty()) {
	r->error ("event missing/empty 'id' att");
    }

    return e;
}

void XMLCALL do_cdata (void *info, const XML_Char *s, int len)
{
    PixScriptXMLReader * r = (PixScriptXMLReader*) info;
    r->cdata.ncat(s,len);
}


void XMLCALL do_start_tag(
    void *info, 
    const XML_Char *name,
    const XML_Char **atts
    )
{
    PixScriptXMLReader * r = (PixScriptXMLReader*) info;

    switch (r->top()) {
    case STATE_INITIAL:
	if (!strcasecmp (name, PIXSCRIBE_ELEMENT) ||
	    !strcasecmp (name, PIXTAG_ELEMENT)) {
	    r->push(STATE_PIXSCRIPT);
	}
	break;

    case STATE_PIXSCRIPT:
	if (!strcasecmp (name, EVENT_ELEMENT)) {
	    r->push(STATE_EVENT);
	    r->event = get_event (r, atts);
	    break;
	}

	if (!strcasecmp (name, PHOTO_ELEMENT)) {
	    r->push(STATE_PHOTO);
	    r->photo = get_photo (r, atts);
	    break;
	}
	r->push(STATE_ERROR);
	break;

    case STATE_EVENT:
	if (!strcasecmp (name, DESC_ELEMENT)) {
	    r->push(STATE_EVENT_PROP);
	    r->start_cdata();
	    break;
	}
	// fall through

    case STATE_EVENT_PROP:
	r->push(STATE_ERROR);
	break;


    case STATE_PHOTO:
	if (!strcasecmp (name, DESC_ELEMENT)) {
	    r->push(STATE_PHOTO_PROP);
	    r->start_cdata();
	    break;
	}
	if (!strcasecmp (name, EVENT_ELEMENT)) {
	    r->push(STATE_EVENT);
	    r->event = get_event (r, atts);
	    r->photo-> events.append(r->event);
	    break;
	}
	// fall through

    case STATE_PHOTO_PROP:
	r->push(STATE_ERROR);
	break;


    case STATE_ERROR:
	r->push(STATE_ERROR);
	break;
    }
}


static void XMLCALL do_end_tag(
    void *info, 
    const XML_Char *name
    )
{
    PixScriptXMLReader * r = (PixScriptXMLReader*) info;

    switch (r->pop()) {
    case STATE_EVENT:
	r-> event = 0;
	break;

    case STATE_EVENT_PROP:
	if (!strcasecmp (name, DESC_ELEMENT)) {
	    r-> event-> desc = r-> cdata;
	    r-> end_cdata();
	    break;
	}
	break;

    case STATE_PHOTO:
	r-> photo = 0;
	break;

    case STATE_PHOTO_PROP:
	if (!strcasecmp (name, DESC_ELEMENT)) {
	    r-> photo-> desc = r-> cdata;
	    r-> end_cdata();
	    break;
	}
	break;
    }
}

