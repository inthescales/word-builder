word-builder
============

Generates real or hypothetical English words based on Latin or Greek roots.

Usage
-----

Word builder can be used to process a single request, or run as a server to accept requests from clients.

To run a request:
    
    wb.rb [tokens...]

To run as a server:

    wb.rb run [port]
	
If no port is specified, the server will run on port 2000.
	
Acceptable input is a sequence of the words (e.g. 'money') and suffixes (e.g. noun-ous) specified in the language files.
Suffix must follow a word of the type listed. For instance, 'noun-ous' must follow a noun, whether it is a basic noun
or another type of word transformed into a noun by another suffixx (like verb-tion).

Html interface
--------------

wb-genhtml.rb will generate an html page with a graphical interface for word builder, styled by wb.css. Any language
files you wish to use must be in the same directory as wb-genhtml.css when you run it. The html communicates via post
request, so a server is necessary to interpret these requests and call into wb.rb.