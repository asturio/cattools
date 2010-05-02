#ifndef _RDF_H_
#define _RDF_H_

#define min(a, b) (a < b) ? a : b

#define WITHLINK 1
#define WITHDESCRIPTION 1

#define L_TITLE 256
#define L_LINK 256
#define L_DESCRIPTION 1024

/* Types */
typedef struct _channel {
    char title[L_TITLE];
    char link[L_LINK];
    char description[L_DESCRIPTION];
} channel;

typedef struct _item {
    char title[L_TITLE];
    char link[L_LINK];
    char description[L_DESCRIPTION];
    struct _item *next;
} item;

typedef struct _rdf {
    channel ch;
    item    *it;
    struct _rdf *next;
} rdf;

typedef struct _rdf_file {
    char url[256];
    char file[256];
    struct _rdf_file *next;
} rdf_file;

item *createItem();
item *freeItems(item *i);
rdf *createRDF();
rdf *freeRDF(rdf *m_rdf);
rdf *freeRDFs(rdf *m_rdf, int del);
rdf_file *createConfig();
rdf_file *freeConfig(rdf_file *config, int del);
rdf_file *readConfig(FILE *fp);
void showConfig(rdf_file *config);
void showRDF(rdf *m_rdf);
void showRDFs(rdf *m_rdf);

#endif
