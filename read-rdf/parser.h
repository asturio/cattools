#ifndef _PARSER_H_
#define _PARSER_H_

#define DOWNLOAD 0

int getContentsOf(char *filebuffer, char *tag, char *buffer, int size);
int readRDF(rdf *m_rdf, FILE *fp, long fsize);
rdf *readRDFs (rdf_file *config);
#endif
