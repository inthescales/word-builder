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
	
Acceptable input is a sequence of the words (e.g. 'money') and affixes (e.g. noun-ous) specified in the language files.
Affixes must follow a word of the type listed. For instance, 'noun-ous' must follow a noun, whether it is a basic noun
or another type of word transformed into a noun by another affix (like verb-tion).

A web interface is in the works to make this all more convenient.