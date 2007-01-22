/* $RCSfile$
 * $Revision$ $Date$
 * Auth: David Loffredo (dave@dave.com)
 * 
 * PixScribe Photo Annotation Tools
 * Copyright (c) 2003-2007 by David Loffredo
 * All Rights Reserved
 * 
 */

#include "support.h"

/* ==================================================
 * VECTOR CLASS
 */

/* Since we allocate data, we need to define proper copy and
 * assignment operations.  These duplicate the data buffers, so
 * use with care!
 */
PixScribeVector::PixScribeVector (const PixScribeVector &other)
{
    unsigned newcap = other.f_capacity;
    register void ** newbuf = (newcap? (new void* [newcap]): 0);
    register void ** oldbuf = other.f_data;

    f_capacity = newcap;
    f_data     = newbuf;
    f_size     = other.f_size;
    register unsigned i = f_size;
    while (i--) *newbuf++ = *oldbuf++;
}

PixScribeVector& PixScribeVector::operator= (const PixScribeVector &other)
{
    /* expand capacity if needed.  Use size instead? */
    if (f_capacity < other.f_capacity) {
	f_capacity = other.f_capacity;
	if (f_data) delete [] f_data;
	f_data = new void* [f_capacity];
    }

    /* copy the contents */
    register void ** newbuf = f_data;
    register void ** oldbuf = other.f_data;

    f_size = other.f_size;

    register unsigned i = f_size;
    while (i--) *newbuf++ = *oldbuf++;
    return *this;
}


PixScribeVector::~PixScribeVector() 
{
    if (f_data) delete [] f_data;
}


void PixScribeVector::append (void * data) 
{
    while (f_size >= f_capacity) expand();
    f_data [f_size++] = data;
}

void PixScribeVector::remove(unsigned i)
{
    /* Back fill the vector */
    for (; i<size()-1; i++)
	f_data[i] = f_data[i+1];

    size(size() -1);
}

void PixScribeVector::remove(void * data)
{
    unsigned sz = size();
    for (unsigned i=0; i<sz; i++) {
	if (data == f_data[i]) { 
	    remove(i);
	    return;
	}
    }
}



void PixScribeVector::expand (unsigned min_extra)
{
    // make sure it is at least 10 and double previous size
    unsigned newcap = f_capacity + min_extra;
    if (newcap < 10) 		newcap = 10;
    if (newcap < 2*f_capacity)	newcap = 2*f_capacity;

    capacity (newcap);
}



void
PixScribeVector::capacity (unsigned newcap)
{
    /* empty on zero capacity */
    if (!newcap) {
	if (f_data) delete [] f_data;
	f_capacity = 0;
	f_size = 0;
	f_data = 0;
	return;
    }

    /* ignore other lesser capacities. */
    if (newcap <= f_capacity) return;

    /* allocate new buffer and copy */
    register void ** newbuf = new void* [newcap];
    register void ** oldbuf = f_data;
    void ** freeme = oldbuf;

    f_data     = newbuf;
    f_capacity = newcap;

    register unsigned i = f_size;
    while (i--) *newbuf++ = *oldbuf++;

    if (freeme) delete [] freeme;
}

/* ==================================================
 * STACK CLASS
 */


void * PixScribeStack::pop() {
    return (f_size? f_data [--f_size]: 0);
}


void * PixScribeStack::top() {
    return (f_size? f_data [f_size-1]: 0);
}


/* ==================================================
 * STRING CLASS
 */

PixScribeString::PixScribeString (const char * str) 
{
    if (!str) p = 0;
    else {
	p = new srep (strlen (str) + 1);
	strcpy (p->data, str);
    }

}

char * PixScribeString::stop_sharing() 
{
    if (p->n) {
	/* no sharing allowed */
	register char * orig =  p->data;
	p-> n--;
	p = new srep (p->sz);
	return strcpy (p->data, orig);
    }
    else return p->data;
}

char * PixScribeString::resize (size_t new_sz) 
{
    if (new_sz) {
	if (!p) {
	    p = new srep (new_sz);
	    p-> data[0] = 0;
	    return p-> data;
	}
	else if (p->n) {		// stop sharing 
	    register char * orig =  p->data;
	    p-> n--; 
	    p = new srep (p->sz > new_sz? p->sz: new_sz);
	    return strcpy (p->data, orig);
	}
	else if (new_sz > p-> sz) {	// expand buffer
	    register char * orig = p-> data;
	    p-> data = new char [new_sz];
	    p-> sz = new_sz;
	    strcpy (p-> data, orig);
	    delete [] orig; 
	    return p-> data;
	}
	else	return p-> data; 	// do not shrink
    }
    else {
	/* deallocate if needed */
	if (p && !(p->n--)) delete p;
	p = 0;
	return 0;
    }
}

PixScribeString& PixScribeString::copy (const char * str) 
{ 
    if (str) {
	size_t len = strlen (str) + 1;
	if (!p)
	    p = new srep (len);
	else if (p->n) {
	    p-> n--;		// stop sharing
	    p = new srep (len);
	}
	else if (len > p-> sz) {
	    delete [] p-> data; 	// expand buffer
	    p-> data = new char[len];
	    p-> sz = len;
	}
	strcpy (p-> data, str);
    }
    else {
	/* deallocate if needed */
	if (p && !(p->n--)) delete p;
	p = 0;
    }
    return *this;
}

PixScribeString& PixScribeString::copy (const PixScribeString & other) 
{
    /* wipe out ours if needed */
    if ( p && !(p->n--)) delete p;
    p = other.p;
    if (p) p-> n++;
    return *this;
}


PixScribeString& PixScribeString::ncopy (const char * str, size_t sz)
{	
    if (str) {
	if (!p)
	    p = new srep (sz+1);
	else if (p->n) {
	    p-> n--;		// stop sharing
	    p = new srep (sz+1);
	}
	else if ((sz+1) > p-> sz) {
	    delete [] p-> data; 	// expand buffer
	    p-> data = new char[sz+1];
	    p-> sz = sz+1;
	}
	strncpy (p-> data, str, sz);
	p-> data[sz] = 0;
    }
    else {
	/* deallocate if needed */
	if (p && !(p->n--)) delete p;
	p = 0;
    }
    return *this;
}

PixScribeString& PixScribeString::ncopy (
    const PixScribeString & other, 
    size_t sz
    )
{
    /* must copy string */
    /* could be a problem if this == other */
    return this-> ncopy (other.p-> data, sz);
}


/* concatenate with another string, tolerates nulls */
PixScribeString& PixScribeString::cat (const char * str) 
{
    // if it's null we do nothing
    if (str) {
	// if we're null we just copy it
	if (!p) {
	    copy(str);
	    return *this;
	}

	// we're not null, see if we're sharing
	if (p->n) {
	    stop_sharing();
	}

	// we're not null and we're not sharing check for size
	size_t total_len = strlen(p->data) + strlen(str) + 1;
	resize(total_len);

		// we're not null, we're not sharing and we're big
		// enough, so copy
	strcat(p->data, str);
    }
    return *this;
}

PixScribeString& PixScribeString::ncat (const char *str,  size_t len) 
{
    // make sure it's not null and we're copying more than 1
    // character
    if (str && len) {
	// if we're null we just copy it
	if (!p) {
	    ncopy(str, len);
	    return *this;
	}

	// we're not null, see if we're sharing
	if (p->n) {
	    stop_sharing();
	}

	// we're not null and we're not sharing check for size
	size_t total_len = strlen(p->data) + len + 1;
	resize(total_len);

	// we're not null, we're not sharing and we're big
	// enough, so copy
	strncat(p->data, str, len);
    }
    return *this;
}
