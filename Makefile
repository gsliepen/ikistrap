all:
	HTML_TIDY=./tidy.config ikiwiki --setup example.setup --refresh

rebuild:
	HTML_TIDY=./tidy.config ikiwiki --setup example.setup --rebuild

tidy:
	HTML_TIDY=./tidy.config tidy -m `find example.html/ -type f -name '*.html'`


.PHONY: all rebuild
