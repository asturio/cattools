#!/usr/bin/python3
# -*- coding: utf-8 -*-

import io
import sys

program_name = "hvb2homebank: HVB-CSV-File in HomeBank CSV-File converter"

def convertFile(creditcard, source, target):
    "Convert a HVB CSV-File in a HomeBank CSV-File"
    if target == source:
        print("Please give as 2 different file names.")
        return
    fd = None
    fdnew = None
    print("Converting", source, "to", target)
    try:
        fd = open(source, "r", encoding="utf-16le")
        fdnew = open(target, "w", encoding="utf-8")
        for line in fd:
            # line = line.decode("utf-8")
            # line = line.decode("utf-16")
            if creditcard:
                newLine = convertLineCC(line)
            else:
                newLine = convertLine(line)
            fdnew.write(newLine + "\n")
    except (IOError, message):
        print("IO-Error:", message)
    finally:
        if fd != None:
            fd.close();
        if fdnew != None:
            fdnew.close()

def convertLine(line):
    "Split the fields of the HVB line and rearenge them to match a HomeBank format."
    splited = line.split(";")
    if len(splited) != 8:
        print("Error splitting the line.")
    # 0-Kontonummer;1-Buchungsdatum;2-Valuta;3-Empfaenger 1;
    # 4-Empfaenger 2;5-Verwendungszweck;6-Betrag;7-Waehrung
    if splited[0] == "Kontonummer":
        # newLine = "date;mode;info;payee;description;amount;category"
        newLine = "date;paymode;info;payee;memo;amount;category;tags"
    else:
        date = transformDate(splited[1])
        description = ""
        for i in range(3, 6):
            if len(description) > 0 and len(splited[i]) > 0:
                description += ":"
            description += splited[i]
        amount = parseFloat(splited[6])
        newLine = "%s;0;;;%s;%.2f;;" % (date, description, amount)
        # newLine = newLine.encode("utf-8")
    return newLine

def convertLineCC(line):
    "Split the fields of the HVB-Creditcard line and rearenge them to match a HomeBank format."
    splited = line.split(";")
    if len(splited) != 8:
        print("Error splitting the line (CC).")
    # 0-Kartennummer; 1-Zeitraum; 2-Belegdatum; 3-Eingangstag; 
    # 4-Text/Verwendungszweck; 5-Kurs; 6-Betrag; 7-Waehrung
    if splited[0] == "Kartennummer":
        newLine = "date;paymode;info;payee;memo;amount;category;tags"
    else:
        date = transformDate(splited[2])
        description = splited[0] + ":" + splited[4]
        amount = parseFloat(splited[6])
        newLine = "%s;0;;;%s;%.2f;;" % (date, description, amount)
        # newLine = newLine.encode("utf-8")
    return newLine

def parseFloat(floatStr):
    "Convert a String in an float. String is in format 1.234,23"
    floatStr = floatStr.replace(".", "") # Remove thousand-points
    floatStr = floatStr.replace(",", ".") # Decimal comma is point
    return float(floatStr)

def transformDate(date):
    aDate = date.split(".")
    date = "%02d-%02d-%04d" % (int(aDate[0]), int(aDate[1]), int(aDate[2]))
    return date

def usage():
    "Displays the usage of the program"
    print("Usage: ",sys.argv[0], " [-c] <HVB-filename> <NewFilename>")
    print("  converts the HVB-filename in a Homebank transaction CSV-File")
    print("  -c Use credit card mode")

def main():
    print(program_name)
    source = None
    target = None
    # read parameters 
    creditcard = False
    if len(sys.argv) > 3 and sys.argv[1] == '-c':
        print("CC-Mode")
        creditcard = True
        sys.argv.pop(1)
    if len(sys.argv) >= 3:
        source = sys.argv[1]
        target = sys.argv[2]

    # parameter bad
    if source == None or target == None:
        usage()
        sys.exit()

    # do the job
    convertFile(creditcard, source, target)

main()
