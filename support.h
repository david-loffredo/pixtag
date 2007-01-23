/* $RCSfile$
 * $Revision$ $Date$
 * Auth: David Loffredo (dave@dave.com)
 * 
 * PixScribe Photo Annotation Tools
 * Copyright (c) 2003-2007 by David Loffredo
 * All Rights Reserved
 * 
 * Supporting data structures.  Simple vector and string class.
 */

#ifndef	SUPPORT_H
#define	SUPPORT_H

#include <string.h>

#ifdef _WIN32
#define strcasecmp _stricmp
#endif

class PixScribeVector {
protected:
    void **	f_data;
    unsigned	f_capacity;
    unsigned	f_size;

public:
    PixScribeVector() : f_data(0), f_capacity(0), f_size(0) {}

    /* proper copy and assignment.  These will duplicate
     * the internal data buffer, so use with care!
     */
    PixScribeVector (const PixScribeVector &other);
    PixScribeVector& operator= (const PixScribeVector &other);

    ~PixScribeVector();

    unsigned size() 			{ return f_size; } 
    void size (unsigned sz) 		{ capacity(sz); f_size = sz; } 

    /* set capacity to zero to deallocate buffer, otherwise
     * this only expands capacity, never decreases it.
     */
    unsigned capacity() 		{ return f_capacity; } 
    void capacity (unsigned newcap);

    void * &operator[] (unsigned i)  	{ return f_data [i]; } 
    void * get (unsigned i)  		{ return f_data [i]; } 
    void append (void * data);
    void empty()			{ f_size = 0; }

    void remove(unsigned i);
    void remove(void * data);
    
    void expand (unsigned minimum_extra = 1);
};

class PixScribeStack : public PixScribeVector {
 public:
    void push (void * stuff) 		{ append (stuff); }
    void * top();
    void * pop();
};



class PixScribeString {
protected:
    class srep {
    public:
	char * data;	// pointer to data
	size_t sz;	// size of string buffer
	unsigned n;	// reference count

	srep (size_t cap) 	{ n=0; sz=cap; data=new char[cap]; }
	~srep() 		{ delete [] data; }
    } * p;

    char * stop_sharing();

public:
    PixScribeString() : p(0) {}
    PixScribeString (const char * str);
    PixScribeString (const PixScribeString & other)
	: p(other.p) 	{ if (p) p->n++; }


    ~PixScribeString() 		{ if ( p && !(p->n--)) delete p; }

    /* Return the C string stored by this object.  Objects may share
     * strings for efficiency, so there are two versions of these
     * functions.  The const versions allow the object to continue
     * sharing, while the others make sure the C string is only used
     * by this object.
     *
     * The pointer is only valid for as long as the object you got it
     * from stays around.
     */
    char * rw()    			{ return p? stop_sharing(): 0; }
    operator char *()    		{ return p? stop_sharing(): 0; }

    char * ro() const 			{ return p? p->data: 0; }
    operator const char *() const 	{ return p? p->data: 0; }

    char operator[] (unsigned i)	{ return p? p->data[i]: 0; }

    /* Returns the length of the string. */
    size_t len() const		{ return (p? strlen(p->data): 0); }

    /* Set size of char buffer, and existing data is copied.  If
     * unset, set to the empty string "".  Returns a pointer to the
     * new char buffer.  capacity() returns the size of the data
     * buffer.
     */
    char * resize (size_t new_sz);
    size_t capacity() const	{ return (p? p->sz: 0); }

    /* Test if unset or empty ("") string */
    int operator!() const 	{ return (!p); }
    int is_null() const		{ return (!p); }
    int is_empty() const 	{ return (!p || !*p->data); }

    /* copy strings, tolerates nulls */
    PixScribeString& copy (const char *);
    PixScribeString& copy (const PixScribeString&);

    /* copy n characters of string, tolerates nulls */
    PixScribeString& ncopy (const char *, size_t);
    PixScribeString& ncopy (const PixScribeString&, size_t);

    /* concatenate with another string, tolerates nulls */
    PixScribeString& cat (const char *);
    PixScribeString& ncat (const char *, size_t);

    /* assignment operator for copy */
    PixScribeString& operator= (const char * s) { return copy(s); }
    PixScribeString& operator= (const PixScribeString& s) { return copy(s); }

    /* concatenates and assigns like strcat */
    PixScribeString & operator+= (const char * s) { return cat(s); }
    PixScribeString & operator+= (const PixScribeString& s) { return cat(s);}
};

#endif 	/* SUPPORT_H */

