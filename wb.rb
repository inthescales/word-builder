require 'rubygems'
require 'json'
require 'socket'

@dictionary = {}
@affixes = {}

@use_exceptions = true

# Import language
def import_dictionary(lang)
	@dictionary = JSON.parse(IO.read(lang+".words"));
end

def import_language(lang)
	@affixes= JSON.parse(IO.read(lang+".affixes"));
end

# Utilities
def is_vowel(letter)
	
	letter.downcase;
	case letter
		when 'a' then return true
		when 'e' then return true
		when 'i' then return true
		when 'o' then return true
		when 'u' then return true
		else return false
	end
end

def is_consonant(letter)
	return !is_vowel(letter)
end

def is_word(token)
	return token.index("-") == nil
end

def is_suffix(token)
	return !is_word(token)
end

def is_free(token)
	case token["category"]
		when "noun" then return true
		when "adj" then return true
		when "verb" then return true
		else return false
	end
end

def is_bound(token)
	return !is_free(token)
end

def get_entry(token)
	if is_word(token)
		return @dictionary[token]
	else
		return @affixes[token]
	end
end

def get_category(token)
	r = token["category"]
	if r == nil then r = token["to"] end
	return r
end

def get_base(entry, prev, nex)
	return get_exception("base", entry, prev, nex)
end

def get_link(entry, prev, nex)
	return get_exception("link", entry, prev, nex)
end

def get_exception(term, entry, prev, nex)

	if @use_exceptions == false or entry["exception"] == nil then return entry[term] end

	entry["exception"].each do |ex|
		bail = false

		if ex[term] == nil
			then bail = true end

		if !bail and ex["prev"] != nil and ex["prev"] != prev
			then bail = true end

		if !bail and ex["next"] != nil and ex["next"] != nex
			then bail = true end

		if !bail
			return ex[term]
		else
			return entry[term]
		end
	
	end
	
end

# Target language spelling rules
def spelling(lang, word)

	if lang == "english"
	
		for i in 0..word.length-1

			# replaces Q + U + cons. with C + U + cons. (e.g. interlocutor)
			if word[i] == 'q' and word[i+1] == 'u' and is_consonant(word[i+2])
				word[i] = 'c'
			end
		end
	end
	
	return word
end

# Generate the words
def generate(input)
	parsed = JSON.parse(input);
	lang = parsed["language"];
	output = []
	cur_cat = nil;
	
	for i in 0..parsed["words"].length-1
	
		current = "";
		entries = []
		
		# Get entries, rout, and check for errors
		for j in 0..parsed["words"][i].length-1
			token = parsed["words"][i][j]
			entries[j] = get_entry(token)
			entry = entries[j]
			ok = true
			
			# Rout - replace the next token with another one specified by the current one
			if entry["rout"] != nil and j < parsed["words"][i].length-1
				entry["rout"].each do |r|
					print "HERE\n"
					if parsed["words"][i][j+1] == r[0]
						parsed["words"][i][j+1] = r[1]
					end
				end
			end
			
			if entry == nil
				print "ERROR: token \"", token, "\" not found."
				ok = false
			end

			if j > 0 and entry["from"] != nil and get_category(entries[j-1]) != entry["from"]
				print "ERROR: cannot use affix \"", comp, "\" following \"", get_category(entries[j-1]), "s\".";
				ok = false
			end
			
			if entry["follows"] != nil
				entry["follows"].each do |ending|
					if j > 0 and entries[j-1]["base"][-ending.length..-1] != ending
						print "ERROR: affix \"", comp, "\" must follow \"", entry["follows"], "\".\n"
						print "(found #{entries[j-1]["base"][-ending.length..-1]}) instead\n"
						ok = false
					end
				end
			end
			
			if ok == false
				output[i] = "nil"
				break
			end
		end
		
		# If there was an error, skip this word
		if output[i] == "nil" then continue end
		
		# Create the word
		for j in 0..parsed["words"][i].length-1
		
			# set up some terms
			add = "";
			comp = parsed["words"][i][j];
			next_comp = parsed["words"][i][j+1]
			prev_comp = parsed["words"][i][j-1]
			entry = entries[j]
			next_entry = entries[j+1]
			prev_entry = entries[j-1]
			base = get_base(entry, prev_comp, next_comp)
			link = get_link(entry, prev_comp, next_comp)
			print "base = ", base, ", link = ", link, "\n"
			
			# Make changes to the word so far ------------

			# Check for final spelling changes
			if entry["tail-mutator"] != nil
				for c in 0..entry["tail-mutator"].length-1
					check = entry["tail-mutator"][c]
					len = check["old"].length
					
					if current[-len..-1] == check["old"]
						current = current[0..current.length-len-1] + check["new"]
					end
				end
			end
			
			# Verb stem changes
			if entry["stem-change"] != nil
				if current[-1,1] == "i" then current += "e" end
				if current[-1,1] == "u" then current += "e" end
			end
			
			# A boring old 'o' links content words. This will probably change
			if is_free(entry) and j > 0 and is_free(prev_entry)
				current += "o"
			end
			
			# Make changes to the new part -------------
			
			# handle cut assimilation or other letter-removers
			if current[-1,1] == "-"
				current = current[0..current.length-2]
				add = add[1, add.length-1]
			end
			
			# Check for padding
			if entry["vowel-padding"] != nil and is_consonant(current[-1,1])
				add += entry["vowel-padding"];
			elsif entry["consonant-padding"] != nil and is_vowel(current[-1,1])
				add += entry["consonant-padding"];
			elsif entry["special-padding"] != nil
				if entry["special-padding"] == "verbstem"
					add += entries[j-1]["conj"]
				end
			end
			
			# If it doesn't assimilate, use base or link as appropriate
			if entry["assimilation"] == nil
				if j == parsed["words"][i].length-1
					add += base
				else
					add += link
				end
				
			# Assimilate to fit with the next sound if necessary
			elsif j < entries.length-1
				assim = entry["assimilation"]
				next_letter = next_entry["base"][0]
				
				assim.each do |type|
					# Check each type of assimilation this entry uses until we find one that matches
					# the next letter
					if type[1].include?(next_letter) or type[1].include?("*")
						# use link form
						if type[0] == "link"
							add = link
							break
							
						# use base form
						elsif type[0] == "base"
							add = base
							break
						
						# use a nasal that fits with following sound
						elsif type[0] == "nasal"
							
							if next_letter == 'm' or next_letter == 'p' or next_letter == 'b'
								add = link + 'm';
							else
								add = link + 'n';
							end
							break
							
						# duplicate following consonant
						elsif type[0] == "double"
							add = link + next_letter
							break

						# remove next letter
						elsif type[0] == "cut"
							add = base + "-"
							break
							
						# replace with a specified alternative
						else
							add += type[0]
							
						end
					end
				end
			end
			
			# handle consonant dissonance
			if entry["consonant-dissonance"] != nil
				for k in 0..current.length-1
					last = ""
					if entry["consonant-dissonance"].include?(current[k])
						last = current[k]
					end
				end
				arr = entry["consonant-dissonance"]
				arr.delete(last)
				add += arr[0]
			end
			
			# Prune matching letters
			count = 0
			for count in 0..add.length
				if add[count] != current[current.length - (count + 1)] then break end
			end
			
			add = add[count..add.length-1]
			
			current += add;
			cur_cat = get_category(entry)
			print "so far: #{current}\n"
		end

		# Apply target language spelling rules and save
		current = spelling("english", current)

		output[i] = current;
	end
	
	return output;
end

# turn a list of words into a json query
def make_query(wordlist)
	ret= "
	{\"language\":\"latin\",
	 \"words\": [
	["

	wordlist.each do |w|
		ret += "\"#{w}\", "
	end

	ret.chomp!(", ")
	
	ret += "]
	]}"

	return ret
end

# Open socket and listen for requests
def run_server(port)
	server = TCPServer.new("localhost", port)

	print "Running server on port #{port}.\n"

	loop do
		
		Thread.start(server.accept) do |client|
		
			print "Connected to client\n"
			while i = client.gets
			
				print "received query: #{i.chomp}.\n"
				words = i.split(" ")

				instring = make_query(words)
				
				g = generate(instring)
				client.puts(g);
				
				print i.chomp, " ==> ", g, "\n";
			
			end
		end
	end
	
	s.close
end

# Startup
import_dictionary("latin");
import_language("latin");

if ARGV.length > 0
	if ARGV[0] == "run"
		# Run as server
		if ARGV.length > 1
			run_server(ARGV[1])
		else
			run_server(2000)
		end
	else
		# Process a request
		query = make_query(ARGV)
		out = generate(query)
		print out, "\n"
	end
end
