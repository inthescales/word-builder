require 'rubygems'
require 'json'
require 'socket'

# Language data
@dictionary = {}
@suffixes = {}
@rules = {}

# Options
@use_exceptions = true

# Import language
def import_dictionary(lang)
	@dictionary = JSON.parse(IO.read(lang+".words"));
end

def import_language(lang)
	@suffixes= JSON.parse(IO.read(lang+".affixes"));
end

def import_rules(lang)
	@rules = JSON.parse(IO.read(lang+".rules"));
end

def import(lang)
	import_dictionary(lang);
	import_language(lang);
	import_rules(lang);
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
		return @suffixes[token]
	end
end

def get_category(token)
	r = token["category"]
	if r == "suffix" then r = token["to"] end
	return r
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
		orderstring = ""
		
		# Preprocess: get entries, verify ordering, rout, and check for errors
		for j in 0..parsed["words"][i].length-1
			token = parsed["words"][i][j]
			entries[j] = get_entry(token)
			entry = entries[j]
			ok = true
			
			# Check for errors on the token
			if entry == nil
				print "ERROR: token \"", token, "\" not found.\n"
				ok = false
			end

			if entry != nil and j > 0 and entry["from"] != nil and get_category(entries[j-1]) != entry["from"]
				print "ERROR: cannot use suffix \"", token, "\" following type \"", get_category(entries[j-1]), "\".\n";
				ok = false
			end
			
			if ok == false
				# If there was an error, return nil
				output[i] = "nil"
				break
			else
				# exception - alter this entry based on surrounding tokens
				if @use_exceptions == true and entries[j]["exception"] != nil
					has_exception = false
					entry["exception"].each do |ex|
					
						ex["req"].each do |cond|
							
							temp = cond[0].to_i
							if temp != 0 and parsed["words"][i][j + temp] == cond[1]
								
								has_exception = true
								break
							end
						end
						
						if has_exception
							entries[j]["base"] = ex["base"]
							entries[j]["link"] = ex["link"]
						end
					end
				end
				
				# rout - replace this token with another based on some rule
				if entry["rout"] != nil
					entry["rout"].each do |r|
						if r[0] == "final-stress"
							if true
								parsed["words"][i][j] = r[1]
								entries[j] = get_entry(r[1])
								break
							end
						elsif r[0] == "default"
							parsed["words"][i][j] = r[1]
							entries[j] = get_entry(r[1])
						end					
					end
				end
				
				# rout-next - replace the next token as specified by the current one
				if entry["rout-next"] != nil and j < parsed["words"][i].length-1
					entry["rout-next"].each do |r|
						if parsed["words"][i][j+1] == r[0]
							parsed["words"][i][j+1] = r[1]
						end
					end
				end
			
				# Add to the type string
				orderstring += entry["category"][0]
			end
		end
		
		# Check that the source language accepts the order of categories
		if !(orderstring =~ Regexp.new(@rules["order"]) )
			print "ERROR: unacceptable ordering of categories\n"
			output[i] = "nil"
		end
		
		# If there was an error, skip this word
		if output[i] == "nil" then next end
		
		# Create the word
		for j in 0..parsed["words"][i].length-1
		
			# set up some terms
			add = "";
			comp = parsed["words"][i][j];
			entry = entries[j]
			next_entry = entries[j+1]
			prev_entry = entries[j-1]
			base = entry["base"]
			link = entry["link"]
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
			
			# Select and modify to the new part -------------
			
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
							add = link + next_letter + "+"
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
			
			# handle cut assimilation or other letter-removers
			if current[-1,1] == "-"
				current = current[0..current.length-2]
				add = add[1, add.length-1]
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
			if current[current.length-1] == "+"
				# '+' blocks pruning. Used in double assimilation
				current = current[0..current.length-2]
				
			else
				for count in 0..add.length - 1
				
					reg = Regexp.new(add[0..count] + "$")
					if current =~ reg
						add = add[count+1..add.length-1]
						break
					end
				end
			end
			
			# Add the new chunk to the working string
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
import("latin")

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
