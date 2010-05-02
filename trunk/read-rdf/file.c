#include <stdio.h>
#include <stdlib.h>
#include <curl/curl.h>
#include <curl/easy.h>
#include <curl/types.h>

#include "file.h"

long filesize (const char *filename) {
    int success = 0;
    long size = 0;

    FILE *f = NULL;

    /* open the file for reading */
    if (!(f = fopen(filename, "rb"))) {
        return -1; /* open failed; bail out */
    }

    /* seek to end, then query file position */
    success = fseek(f, 0, SEEK_END)==0 && (size = ftell(f))!=-1;

    /* the file must be closed - even if feek() or ftell() failed. */
    if (fclose(f)!=0) {
        fprintf(stderr, "error in filesize(\"%s\"): fclose() call failed.\n",
                filename);
        exit(EXIT_FAILURE);
    }

    return success ? size : -1;
}

int downloadFile(char *filename, char *url) {
    CURL *curl = NULL;
    FILE *fp = NULL;
    CURLcode res = 0;

    curl_global_init(CURL_GLOBAL_DEFAULT);
    curl = curl_easy_init(); 
    if (curl) {
        fp = fopen(filename, "w");

        if(!fp) {
            fprintf (stderr, "Couldn't open file for write (%s)\n", filename);
            return -1; /* failure, can't open file to write */
        }
        printf("  %s: ", url);
        fflush(stdout);
        curl_easy_setopt(curl, CURLOPT_URL, url);
        curl_easy_setopt(curl, CURLOPT_FILE, fp);
        res = curl_easy_perform(curl);

        fclose(fp); /* close the local file */
        printf("OK\n");
        curl_easy_cleanup(curl); /* always cleanup */

        if(CURLE_OK != res) { /* we failed */
            fprintf(stderr, "curl told us %d\n", res); 
            return -1;
        } 
    }
    curl_global_cleanup();
    return 0;
}
