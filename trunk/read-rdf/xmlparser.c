#include <stdio.h>
#include <expat.h>
#include <string.h>

#include "read-rdf2.h"

#define BUFFSIZE        8192
#define strEq(A,B)      (strcmp(A,B) ? 0 : 1)

enum _elements { CHANNEL = 1, ITEM, TITLE, LINK, DESCRIPTION };

/*
 * push to stack new channels and items
 * if in channel we fill channel.*
 * if in item we fill item.*
 */

/* {{{ */
/* 
 * Interesting ELEMENTS:   
 * <channel>
 *      <title>
 *      <link>
 *      <description>
 *
 * <item>
 *      <title>
 *      <link>
 *      <description>
 *
 */
/* }}} */

typedef struct _stack {
    int e;
    int se;
    char *text;
    size_t size;
    void *data; /* Don't free this */
    size_t d_size;
    struct _stack *p_last;
} stack;

typedef struct _userdata {
    stack *st;
    rdf *p_rdf;
} userdata;

userdata *createUserData() {
    userdata *ud = NULL;
    ud = (userdata *) malloc(sizeof(userdata));
    if (ud) {
        bzero(ud, sizeof(userdata));
    }
    return ud;
}

stack *createStack() {
    stack *st = NULL;
    st = (stack *) malloc(sizeof(stack));
    if (st) {
        bzero(st, sizeof(stack));
    }
    return st;
}

int freeStack(stack *st) {
    if (st) {
        if (st->text) {
            free(st->text);
        }
        free(st);
    }
    return 1;
}

int freeStackR(stack *st) {
    if (st) {
        freeStackR(st->p_last);
        freeStack(st);
    }
    return 1;
}

int freeUserData(userdata *ud) {
    if (ud) {
        freeStackR(ud->st);
        free(ud);
    }
    return 1;
}

stack *push(stack *st, stack *n) {
    if (n) {
        n->p_last = st;
    }
    return n;
}

stack *pop(stack *st) {
    stack *this = NULL;
    if (st) {
        this = st;
        st = st->p_last;
        freeStack(this);
    }
    return st;
}

char *rtrim(char *s) {
    char *p = s + strlen(s) - 1;
    while (p >= s && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) {
        *(p--) = '\0';
    }
    return s;
}

char *ltrim(char *s) {
    char *p = s;
    int len = 0;
    while (p && *p && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) {
        p++;
    }
    len = strlen(p);
    s = memmove(s, p, len);
    s[len] = '\0';
    return s;
}

static void *myrealloc(char *ptr, size_t size) {
    if (ptr) {
        return realloc(ptr, size);
    } else {
        return malloc(size);
    }
}

static int getElement(const char *el) {
    if (strEq(el, "channel")) {
        return CHANNEL;
    } else if (strEq(el, "item")) {
        return ITEM;
    } else if (strEq(el, "title")) {
        return TITLE;
    } else if (strEq(el, "link")) {
        return LINK;
    } else if (strEq(el, "description")) {
        return DESCRIPTION;
    }
    return 0;
}

int set_string(userdata *ud) {
    stack *st = NULL;
    if (ud) {
        st = ud->st;
        if (ud->p_rdf && st && st->text) {
            ltrim(rtrim(st->text));
            strncpy((char *)(st->data), st->text, st->d_size - 1);

            free(st->text);
            st->text = NULL;
            st->size = 0;
        }
    }
    return 0;
}

static void XMLCALL xmlChars(void *data, const XML_Char *s, int len) {
    stack *st = NULL;
    userdata *ud = (userdata *) data;

    if (len > 0) {
        st = ud->st;
        if (st) {
            st->text = myrealloc(st->text, st->size + len + 1);
            memcpy(&(st->text[st->size]), s, len);
            st->size += len;
            st->text[st->size] = '\0';
        }
    }
}

static void XMLCALL xmlStart(void *data, const char *el, const char **attr) {
    stack *st = NULL;
    userdata *ud = NULL;
    item *it = NULL;
    
    int i_el = getElement(el);

    ud = (userdata *) data;
    
    if (i_el == CHANNEL || i_el == ITEM) {
        st = createStack();
        st->e = i_el;
        ud->st = push(ud->st, st);

        /* Add item */
        if (i_el == ITEM) {
            it = createItem();
            it->next = ud->p_rdf->it;
            ud->p_rdf->it = it;
        }
    } else if (i_el == TITLE || i_el == LINK || i_el == DESCRIPTION) {
        if (ud->st) {
            ud->st->se = i_el;

            if (ud->st->e == CHANNEL) {
                switch (ud->st->se) {
                case TITLE: 
                    ud->st->data = &(ud->p_rdf->ch.title); 
                    ud->st->d_size = L_TITLE;
                    break;
                case LINK: 
                    ud->st->data = &(ud->p_rdf->ch.link); 
                    ud->st->d_size = L_LINK;
                    break;
                case DESCRIPTION: 
                    ud->st->data = &(ud->p_rdf->ch.description);
                    ud->st->d_size = L_DESCRIPTION;
                    break;
                }
            } else if (ud->st->e == ITEM) {
                switch (ud->st->se) {
                case TITLE: 
                    ud->st->data = &(ud->p_rdf->it->title); 
                    ud->st->d_size = L_TITLE;
                    break;
                case LINK: 
                    ud->st->data = &(ud->p_rdf->it->link); 
                    ud->st->d_size = L_LINK;
                    break;
                case DESCRIPTION: 
                    ud->st->data = &(ud->p_rdf->it->description);
                    ud->st->d_size = L_DESCRIPTION;
                    break;
                }
            }
        }
    }
}

static void XMLCALL xmlEnd(void *data, const char *el) {
    userdata *ud = (userdata *) data;
    int i_el = getElement(el);

    if (i_el == CHANNEL || i_el == ITEM) {
        ud->st = pop(ud->st);
    } else if (i_el == TITLE || i_el == LINK || i_el == DESCRIPTION) {
        if (ud->st) {
            /* Copy text to right place */
            set_string(ud);
            ud->st->se = 0;
        }
    }
}

void cleanup(userdata *ud, FILE *fp, XML_Parser p) {
    freeUserData(ud);
    if (p) {
        XML_ParserFree(p);
    }
    if (fp != stdin) {
        fclose(fp);
    }
}

rdf *readRDF(char *filename) {
    userdata *ud = NULL;
    rdf *p_rdf = NULL;
    FILE *fp = stdin;
    XML_Parser p = NULL;

    p = XML_ParserCreate(NULL);
    if (!p) {
        fprintf(stderr, "ERROR: Couldn't allocate memory for parser.\n");
        return NULL;
    }

    if (filename) {
        fp = fopen(filename, "r");
        if (!fp) {
            fprintf(stderr, "ERROR: Couldn't open file %s for read.\n", filename);
            cleanup(ud, stdin, p);
            return NULL;
        }
    }

    ud = createUserData();
    ud->p_rdf = createRDF();
    XML_SetUserData(p, ud);
    XML_SetElementHandler(p, xmlStart, xmlEnd);
    XML_SetCharacterDataHandler(p, xmlChars);

    for (;;) {
        int done = 0;
        int len = 0;
        char Buff[BUFFSIZE] = "";

        len = fread(Buff, 1, BUFFSIZE, fp);
        if (ferror(fp)) {
            fprintf(stderr, "ERROR: Read error\n");
            cleanup(ud, fp, p);
            return NULL;
        }
        done = feof(fp);

        if (XML_Parse(p, Buff, len, done) == XML_STATUS_ERROR) {
            fprintf(stderr, "ERROR: Parse error at line %d:\n%s\n",
                    XML_GetCurrentLineNumber(p),
                    XML_ErrorString(XML_GetErrorCode(p)));
            cleanup(ud, fp, p);
            return NULL;
        }

        if (done)
            break;
    }
    p_rdf = ud->p_rdf;
    cleanup(ud, fp, p);
    return p_rdf;
}

rdf *readRDFs (rdf_file *config) {
    rdf *new = NULL;
    rdf *ret = NULL;
    /* struct stat stats; */
  
    if (DOWNLOAD) {
        printf("Downloading and ");
    }
    printf("reading Newsfeeds.\n");
    while (config) {
        /* Download File */
        if (DOWNLOAD) {
            downloadFile(config->file, config->url);
        }

        /* Read file */
        new = readRDF(config->file);

        if (new) {
            if (ret) {
                new->next = ret->next;
                ret->next = new;
            } else {
                ret = new;
            }
        }
            
        config = config->next;
    }
    return ret;
}
