#!/bin/bash

DBFILE=../../../data/bdays

java -cp /usr/share/java/hsqldb.jar org.hsqldb.Server -database.0 file:${DBFILE} -dbname.0 bdays
