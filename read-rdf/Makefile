CC=gcc
LDFLAGS=`curl-config --cflags --libs`
#CFLAGS=-g -ggdb -Wall 
CFLAGS=-g -ggdb -O -Wall 

OBJS=file.o parser.o rdf.o read-rdf.o
OBJS2=file.o rdf.o xmlparser.o read-rdf2.o

all:	read-rdf  read-rdf2

%.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@

read-rdf: $(OBJS)
	$(CC) $(LDFLAGS) $(OBJS) -o $@


read-rdf2: $(OBJS2)
	$(CC) $(LDFLAGS) -lexpat $(OBJS2) -o $@

clean:
	rm -f read-rdf $(OBJS) read-rdf2 $(OBJS2) http_*
