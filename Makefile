all:
	HTML_TIDY=./tidy.config ikiwiki --setup example.setup --refresh

rebuild:
	HTML_TIDY=./tidy.config ikiwiki --setup example.setup --rebuild


.PHONY: all rebuild
