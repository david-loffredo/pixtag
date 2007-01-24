/* $RCSfile$
 * $Revision$ $Date$
 * Auth: David Loffredo (dave@dave.com)
 * 
 * PixScribe Photo Annotation Tools
 * Copyright (c) 2003-2007 by David Loffredo
 * All Rights Reserved
 * 
 */


#ifndef PIXSCRIBE_H
#define PIXSCRIBE_H

// make an int handle and keep the data internal?
struct PixScribeDB;
struct PixScribePhoto;
struct PixScribeEvent;

PixScribeDB * pixscribe_new_db();
void pixscribe_release_db (
    PixScribeDB * db
    );

int pixscribe_report (
    PixScribeDB * db
    );

int pixscribe_read_xml (
    PixScribeDB * db, 
    const char * filename
    );

int pixscribe_write_xml (
    PixScribeDB * db, 
    const char * outname
    );

int pixscribe_update_from_directory (
    PixScribeDB * db, 
    const char * dirname
    );

int pixscribe_is_photo_file (
    const char * filename
    );

/* default pattern used for new photos */
PixScribePhoto * pixscribe_default_photo(
    PixScribeDB * db
    );

char * pixscribe_get_photo_file (PixScribePhoto *);
void   pixscribe_set_photo_file (PixScribePhoto *, const char *);

char * pixscribe_get_photo_desc (PixScribePhoto *);
void   pixscribe_set_photo_desc (PixScribePhoto *, const char *);

void pixscribe_add_photo_event (
    PixScribePhoto * p, 
    PixScribeEvent * e
    );



PixScribeEvent * pixscribe_find_event (
    PixScribeDB * db,
    const char * id
    );

PixScribeEvent * pixscribe_make_event (
    PixScribeDB * db,
    const char * id
    );

char * pixscribe_get_event_id   (PixScribeEvent *);
void   pixscribe_set_event_id   (PixScribeEvent *, const char *);

char * pixscribe_get_event_desc (PixScribeEvent *);
void   pixscribe_set_event_desc (PixScribeEvent *, const char *);

#endif /* PIXSCRIBE_H */

