headerdoc2html -j -o mEmail/Documentation mEmail/mEmail.h     


gatherheaderdoc mEmail/Documentation


sed -i.bak 's/<html><body>//g' mEmail/Documentation/masterTOC.html
sed -i.bak 's|<\/body><\/html>||g' mEmail/Documentation/masterTOC.html
sed -i.bak 's|<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">||g' mEmail/Documentation/masterTOC.html