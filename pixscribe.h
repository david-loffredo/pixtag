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

// or make this an int handle and keep the data internal?
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

#endif /* PIXSCRIBE_H */

