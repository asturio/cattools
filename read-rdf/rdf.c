#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>

#include "rdf.h"

/*
 * Functions
 */

/* */
item *createItem() {
    item *i = NULL;
    i = (item *) malloc(sizeof(item));
    if (i) {
        bzero(i, sizeof(item));
    }
    return i;
}

/* */
item *freeItems(item *i) {
    if (i) {
        i->next = freeItems(i->next);
        free(i);
        i = NULL;
    }
    return i;
}

/* */
rdf_file *createConfig() {
    rdf_file *r = NULL;
    r = (rdf_file *) malloc(sizeof(rdf_file));
    if (r) {
        bzero(r, sizeof(rdf_file));
    }
    return r;
}

/* */
rdf_file *readConfig(FILE *fp) {
    char linebuf[1024] = "";
    char newbuf[1024] = "";
    char *pnb = NULL;
    rdf_file *new = NULL;
    rdf_file *ret = NULL;
    int i = 0;
    
    while (fgets(linebuf, 1024, fp)) {
        pnb = newbuf;
        /* Translate URL in Filename */
        for (i = 0; linebuf[i]!= '\0' && linebuf[i]!= '\n'; i++) { 
            if (linebuf[i] == ' ') {
                continue;
            }
            if (linebuf[i] == '.' || linebuf[i] == ':' || linebuf[i] == '/' 
                    || linebuf[i] == '?' || linebuf[i] == ',' || linebuf[i] == '&') {
                if (*(pnb-1) != '_') {
                    *(pnb++) = '_'; 
                }
            } else {
                *(pnb++) = linebuf[i]; 
            }
        }
        *pnb = linebuf[strlen(linebuf)-1] = '\0';

        new = createConfig();
        snprintf(new->url, sizeof(new->url), "%s", linebuf);
        snprintf(new->file, sizeof(new->url), "%s.rr", newbuf);
        if (ret) {
            new->next = ret->next;
            ret->next = new;
        } else {
            ret = new;
        }
    }
    return ret;
}

/* */
void showConfig(rdf_file *config) {
    while (config) {
        printf("URL: (%s), File: (%s) \n", config->url, config->file);
        config = config->next;
    }
}

/* */
rdf_file *freeConfig(rdf_file *config, int del) {
    if (config) {
        config->next = freeConfig(config->next, 1);
        if (del) {
            free(config);
            config = NULL;
        }
    }
    return config;
}

/* */
rdf *createRDF() {
    rdf *r = NULL;
    r = (rdf *) malloc(sizeof(rdf));
    if (r) {
        bzero(r, sizeof(rdf));
    }
    return r;
}

/* */
rdf *freeRDF(rdf *m_rdf) {
    if (m_rdf) {
        m_rdf->it = freeItems(m_rdf->it);
        free(m_rdf);
        m_rdf = NULL;
    }
    return m_rdf;
}

/* */
rdf *freeRDFs(rdf *m_rdf, int del) {
    if (m_rdf) {
        m_rdf->next = freeRDFs(m_rdf->next, 1);
        if (del) {
            m_rdf = freeRDF(m_rdf);
        }
    }
    return m_rdf;
}

/* */
void showRDF(rdf *m_rdf) {
    item *i;
    if (m_rdf) {
        printf("(%s)", m_rdf->ch.title);
        if (WITHLINK) {
            printf("(%s)", m_rdf->ch.link);
        }
        printf("\n");
        if (WITHDESCRIPTION) {
            printf("(%s)\n", m_rdf->ch.description);
        }
        
        i = m_rdf->it;
        while (i) {
            printf(" -> %s\n", i->title);
            if (WITHLINK) {
                printf("  >> %s <<\n", i->link);
            }
            if (WITHDESCRIPTION && i->description[0]) {
                printf("  => %s <=\n", i->description);
            }
            sleep(strlen(i->title)/6);
            i = i->next;
        }
    }
}

/* */
void showRDFs (rdf *m_rdf) {
    while (m_rdf) {
        showRDF(m_rdf);
        m_rdf = m_rdf->next;
    }
}
