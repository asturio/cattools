#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "read-rdf.h"

/* Return number of bytes */
/* Copy in "buffer", the maximum of "size" bytes of the contents of a "tag"
 * found in "filebuffer */
int getContentsOf(char *filebuffer, char *tag, char *buffer, int size) {
    char *pbegin = NULL;
    char *pend = NULL;
    char *ptemp = NULL;
    char temp[256] = "";

    //printf("Getting contents of %s\n", tag);
    
    snprintf(temp, sizeof(temp), "<%s", tag);
    ptemp = (char *) strstr(filebuffer, temp);
    if (ptemp) {
        pbegin = (char *) strstr(ptemp, ">");
        if (pbegin) {
            if (*(pbegin-1) == '/') {
                buffer[0] = '\0';
                return 0;
            }
            pbegin++;
            // ^M auch 0x0d ? 0x0a ?
            while (*pbegin == ' ' || *pbegin == '\n' || *pbegin == '\r') pbegin++;
            snprintf(temp, sizeof(temp), "</%s", tag);
            pend = (char *) strstr(pbegin, temp);
            if (pend) {
                while (*(pend-1) == ' ' || *(pend-1) == '\n' || *(pend-1) == '\r') pend--;
                if (pend - pbegin > size) {
                    fprintf(stderr, "Warning... buffer too small to contain '%s'.\n", tag);
                }
                strncpy(buffer, pbegin, min(pend-pbegin, size));
                buffer[min(size, pend-pbegin)] = '\0';
            } else {
                fprintf(stderr, "Warning: Tag '%s' has not end tag\n", tag);
                buffer[0] = '\0';
                return 0;
            }
        } else {
            fprintf(stderr, "Warning: Tag '%s' looks strange\n", tag);
            buffer[0] = '\0';
            return 0;
        }
    } else {
        fprintf(stderr, "Warning: Tag '%s' not found.\n", tag);
        buffer[0] = '\0';
        return 0;
    }

    return pend-pbegin;
}

/* Review m_rdf must exist */
int readRDF(rdf *m_rdf, FILE *fp, long fsize) {
    int bcount = 0;
    char *filebuffer = NULL;
    char buff[100000];
    char *pbuff = NULL;
    item *myItem = NULL;

    filebuffer = (char *) malloc(fsize+1);
    if (!filebuffer) {
        fprintf(stderr, "Can't alloc memory for filebuffer!\n");
        return 0;
    }
    printf("   Alloced %ld bytes for file.", fsize);

    bzero(filebuffer, fsize+1);

    /* Fill filebuffer */
    bcount = fread(filebuffer, fsize, 1, fp);
    /* 
    if (bcount) { /o If read complete, file may be larger than buffer o/
        printf("Buffer too small to contain file.\n");
        exit(1);
    }
    */
    if (!filebuffer[0]) { /* Empty file */
        printf("File error. File is empty\n");
        free(filebuffer);
        return 1;
    }
   
    /* Set Channel info */
    bcount = getContentsOf(filebuffer, "channel", buff, sizeof(buff));
    getContentsOf(buff, "title", m_rdf->ch.title, sizeof(m_rdf->ch.title));
    getContentsOf(buff, "link", m_rdf->ch.link, sizeof(m_rdf->ch.link));
    getContentsOf(buff, "description", m_rdf->ch.description, sizeof(m_rdf->ch.description));

    /* Pointer auf erstes item zeigen */
    pbuff = (char *)strstr(filebuffer, "</channel");
    if (!pbuff) {
        printf("\nChannel end not found, dumping buffer: \n>>>\n%s\n<<<\n", filebuffer);
        free(filebuffer);
        exit(1);
    }
    pbuff = (char *)strstr(pbuff, "<item"); /* RDF FORMAT */
    if (!pbuff) {
        pbuff = (char *) strstr(filebuffer, "<item"); /* RSS Format */
        printf(" RSS-Format\n");
    } else {
        printf(" RDF-Format\n");
    }

    bcount = 0;
    if (pbuff) { /* If <item found */
        while (pbuff) {
            getContentsOf(pbuff, "item", buff, sizeof(buff)); /* read new Item */
            myItem = createItem();
            /* Ignore empty items */
            if (!getContentsOf(buff, "title", myItem->title, sizeof(myItem->title))) {
                pbuff = (char *)strstr(pbuff+1, "<item"); /* Find next <item */
                myItem = freeItems(myItem);
                continue;
            }
            getContentsOf(buff, "link", myItem->link, sizeof(myItem->link));
            getContentsOf(buff, "description", myItem->description, sizeof(myItem->description));
            bcount++;
            
            myItem->next = m_rdf->it; /* Insert item */
            m_rdf->it = myItem;
            
            pbuff = (char *)strstr(pbuff+1, "<item"); /* Find next <item */
        }
    }
    else {
        printf("No items found\n");
    }
    //printf ("(%d) items found.\n", bcount);
    free(filebuffer);
    return 0;
}

/* */
rdf *readRDFs (rdf_file *config) {
    rdf *new = NULL;
    rdf *ret = NULL;
    FILE *fp = NULL;
    long fsize = 0;
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
        fsize = filesize(config->file);
        if (fsize > 0) {
            fp = fopen(config->file, "r");
            if (!fp) {
                printf("  couldn't open file %s for read.\n", config->file);
                config = config->next;
                continue;
            }
            new = createRDF();
            if (readRDF(new, fp, fsize)) {
                new = freeRDF(new);
                config = config->next;
                continue;
            }
            fclose(fp);
        } else {
            config = config->next;
            continue;
        }

        if (ret) {
            new->next = ret->next;
            ret->next = new;
        } else {
            ret = new;
        }
            
        config = config->next;
    }
    return ret;
}
