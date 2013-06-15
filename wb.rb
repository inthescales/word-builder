require 'rubygems'
require 'json'
require 'socket'

@dictionary = {}
@affixes = {}

# Import language
def import_dictionary(lang)
	@dictionary = JSON.parse(IO.read(lang+".words"));
end

def import_language(lang)
	@affixes= JSON.parse(IO.read(lang+".affixes"));
end

# Utilities:
def is_vowel(letter)
	
	letter.downcase;
	case letter
		when 'a' then return true;
		when 'e' then return true;
		when 'i' then return true;
		when 'o' then return true;
		when 'u' then return true;
		else return false
	end
end

def is_consonant(letter)
	return !is_vowel(letter);
end

def is_content(word)
	case word["category"]
		when "noun" then return true;
		when "adj" then return true;
		when "verb" then return true;
		else return false
	end
end

# Main
def generate(input)
	parsed = JSON.parse(input);
	lang = parsed["language"];
	output = []
	cur_cat = nil;
	
	for i in 0..parsed["words"].length-1
	
		current = "";
		entries = []
		for j in 0..parsed["words"][i].length-1
		
			add = "";
			comp = parsed["words"][i][j];
			
			if comp.index('-') == nil
				# The component is a free morpheme
				entry = @dictionary[comp]
				entries[j] = entry;
				
				# Check the dictionary for this word
				if entry == nil
					print "ERROR: word \"", comp, "\" not found."
					continue
				end

				# A boring old 'o' links content words. This will probably change
				if is_content(entry) and j > 0 and is_content(entries[j-1])
					current += "o"
				end
				
				# If it doesn't assimilate, use link form
				if entry["assimilation"] == nil
					add = entry["link"]
					
				elsif j < parsed["words"][i].length-1
					# Assimilate to fit with the next sound if necessary
					assim = entry["assimilation"]
					next_letter = @dictionary[parsed["words"][i][j+1]]["link"][0]
					
					assim.each do |type|
						print next_letter, "\n"
						print type, "\n"
						if type[1].include?(next_letter) or type[1].include?("*")
							
							if type[0] == "link"
								# use link form
								add = entry["link"]
								break
								
							elsif type[0] == "base"
								# use base form
								add = entry["base"]
								break
								
							elsif type[0] == "nasal"
								# use a nasal that fits with following sound
								if next_letter == 'm' or next_letter == 'p' or next_letter == 'b'
									add = entry["link"] + 'm';
								else
									add = entry["link"] + 'n';
								end
								break
								
							elsif type[0] == "double"
								# duplicate following consonant
								add = entry["link"] + next_letter
								break

							elsif type[0] == "cut"
								# remove next letter
								add = entry["base"] + "-"
								break
								
							else
								# custom assimilation - replace
								add += type[0]
								
							end
						end
					end
				end
				cur_cat = entry["category"]
				
			else
				# The component is an affix
				entry = @affixes[comp]
				entries[j] = entry;
				
				# Error handling
				bad = false
				if entry == nil
					print "ERROR: affix \"", comp, "\" not found in language \"", lang, "\"\n";
					bad = true
				end

				if cur_cat != entry["from"]
					print "ERROR: cannot use affix \"", comp, "\" after \"", cur_cat, "\".";
					bad = true
				end
				
				if entry["follows"] != nil
					entry["follows"].each do |ending|
						if j > 0 and entries[j-1]["base"][-ending.length..-1] != ending
							print "ERROR: affix \"", comp, "\" must follow \"", entry["follows"], "\".\n"
							print "(found #{entries[j-1]["base"][-ending.length..-1]})\n"
							bad = true
						end
					end
				end

				if bad
					j = parse["words"][i].length
					continue
				end

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

				# Check for padding
				if entry["vowel-padding"] != nil and is_consonant(current[-1,1])
					current += entry["vowel-padding"];
				elsif entry["consonant-padding"] != nil and is_vowel(current[-1,1])
					current += entry["consonant-padding"];
				elsif entry["special-padding"] != nil
					if entry["special-padding"] == "verbstem"
						current += entries[j-1]["conj"]
					end
				end
				
				# Add the new component
				if j == parsed["words"][i].length-1
					add = entry["base"];
				else
					add = entry["link"];
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
				
				cur_cat = entry["to"];
			end
			
			# handle assimilation that cuts off a letter (cut)
			if current[-1,1] == "-"
				current = current[0..current.length-2]
				add = add[1, add.length-1]
			end
			
			current += add;
			print "so far: #{current}\n"
		
		end

		current = spelling("english", current)

		output[i] = current;
	end
	
	return output;
end

# apply spelling rules
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
