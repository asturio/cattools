#include <stdio.h>
#include <sys/time.h>
#include <stdlib.h>

#include "read-rdf.h"

int main (int argc, char **argv) {
    FILE *cfp = NULL;
    rdf *myRdf = NULL;
    rdf_file *config = NULL;
    struct timeval tv;
    struct timeval now;

    gettimeofday(&tv, NULL);

    if (argc!= 2) {
        printf("Please enter a filename.\n");
        exit(1);
    }
  
    cfp = fopen(argv[1], "r");
    if (!cfp) {
        printf("couldn't open file for read.\n");
        exit(1);
    }
    config = readConfig(cfp);
    fclose(cfp);

    if (config) {
        myRdf = readRDFs(config);
        while (myRdf) {
            showRDFs(myRdf);
            gettimeofday(&now, NULL);
            if (ONCE) {
                break;
            }
            if (now.tv_sec - tv.tv_sec >= 30 * 60) { // 1/2 Hour 
                printf("\n   ==>  RELOADING <==  \n");
                tv = now;
                myRdf = freeRDFs(myRdf, 1);
                myRdf = readRDFs(config);
            }
        }
        if (!myRdf) {
            printf("\nRDFs Error.\n");
        }
        if (myRdf) {
            myRdf = freeRDFs(myRdf, 1);
        }
        config = freeConfig(config, 1);
    }
    else printf("\nConfigfile ERROR.\n");
    return 0;
}
