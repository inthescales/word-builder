require 'json'

# import a language's words and affixes from json files and fill lists with the contents
def parse_lang(lang)

	word_parse = JSON.parse(IO.read(lang+".words"));
	affix_parse = JSON.parse(IO.read(lang+".affixes"));
	
	if word_parse == nil or affix_parse == nil
		return false
	end
	
	@word_list[lang] = {}
	@affix_list[lang] = {}

	word_parse.each do |i|
		if @word_list[lang][i[1]["category"]] == nil
			@word_list[lang][i[1]["category"]] = []
		end
		
		if i[1]["hidden"] != "true"
			@word_list[lang][i[1]["category"]] << [i[0],i[0]]
		end
	end

	affix_parse.each do |i|
		from = i[1]["from"]
		to = i[1]["to"]
		name = i[0].split("-")[1]
		description = i[1]["description"]
		
		if @affix_list[lang][from] == nil
			@affix_list[lang][from] = {}
		end
		
		if @affix_list[lang][from][to] == nil
			@affix_list[lang][from][to] = []
		end
		
		if i[1]["hidden"] != "true"
			@affix_list[lang][from][to] << [i[0],description]
		end
	end
	
	return true
end

# contains the data needed to create a drop-down list for one category
class Dropmenu

	attr_accessor :name

	def initialize(name, list)
		@name = name
		@list = list
	end
	
	def generate
		r = "<select id=\"menu_#{@name}\" size=\"6\">\n"
		@list.each do |i|
			displayname = i[1].gsub(/_/, ' ')
			r += "\t<option value=\"#{i[0]}\">#{displayname}</option>\n"
		end
		r += "</select>\n"
		return r
	end
	
	def generate_button
		r = "<button id=\"button_#{@name}\" class=\"addbutton\">"
		r += "add"
		r += "</button>\n"
		return r
	end

end

# initial setup
@word_list = {}
@affix_list = {}
supported_languages = ["latin"]
dropmenu = {}
f = File.open("wb.html", "w");

# import languages and make sure they're valid
supported_languages.each do |lang|

	if parse_lang(lang)
		dropmenu[lang] = {}
		dropmenu[lang]["word"] = []
		dropmenu[lang]["affix"] = {}
	else
		supported_languages.delete(lang)
	end
end

# build dropmenus for the imported languages
supported_languages.each do |lang|

	@word_list[lang].each do |k, v|

		dropmenu[lang]["word"] << Dropmenu.new(k, v)
	end

	@affix_list[lang].each do |k, v|
		
		dropmenu[lang]["affix"][k] = {}
		
		["noun", "adj", "verb"].each do |k2|
			list = @affix_list[lang][k][k2]
			if list == nil then list = [] end
			dropmenu[lang]["affix"][k][k2] = Dropmenu.new(k+"_"+k2, list)
		end
	end

end

# Use this when I put this on the server
# <link rel=\"stylesheet\" href=\"/wb.css\" type=\"text/css\">\n
# Use this when it's not
# <link rel=\"stylesheet\" href=\"wb.css\" type=\"text/css\">\n

head = "
<!DOCTYPE html>\n
<html>\n
<head>\n
	<title>Word builder</title>\n
	<link rel=\"stylesheet\" href=\"wb.css\" type=\"text/css\">\n
	<link rel=\"stylesheet\" href=\"http://code.jquery.com/ui/1.10.3/themes/smoothness/jquery-ui.css\" />	
	<script src=\"http://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js\"></script>
	<script src=\"http://code.jquery.com/ui/1.10.3/jquery-ui.js\"></script>
</head>\n
<body>\n
";

f.write(head)

# Write upper bar
f.write "<div class=\"topdiv\" >\n"
f.write "</div>\n\n"

# Write options div
f.write "<div class=\"langsel\" >\n"
f.write "<select id=\"menu_language\">\n"
supported_languages.each do |i|
	f.write "<option value=\"#{i}\">#{i}</option>\n"
end
f.write "</select>\n"
f.write "</div>\n\n"

# Write language divs
supported_languages.each do |lang|

	f.write "<div id=\"#{lang}_top\" class=\"langdiv\">\n"
	
	f.write "<div id=\"#{lang}_words\" class=\"worddiv\">\n"
	dropmenu[lang]["word"].each do |i|
		f.write "<div class=\"catdiv\">\n"
		f.write i.generate()
		f.write i.generate_button()
		f.write "</div>\n"
	end
	f.write "</div>\n\n"
	
	dropmenu[lang]["affix"].each do |k, v|
	
		f.write "<div id=\"#{lang}_#{k}_affixes\" class=\"affixdiv\">\n"
		f.write "<div class=\"catdiv\" ></div>\n"
		v.each do |k2, v2|
		
			f.write "<div class=\"catdiv\">\n"
			f.write v2.generate()
			f.write v2.generate_button()
			f.write "</div>\n"
		end
		
		f.write "</div>\n"
	end	
	
	f.write "</div>\n\n"
end

# Output div
f.write "<div class=\"outputdiv\">\n"
f.write "<div id=\"elements_list\" ></div>\n"
f.write "<div id=\"output\">\n</div>\n"
f.write "<p id=\"definition\"></p>\n"
f.write "<button id=\"button_submit\" disabled>make word!</button>\n"
f.write "<button id=\"button_clear\">clear input</button>\n"
f.write "</div>\n"

# Javascript ================================

# Startup function
scriptcode = "
<script>
var pre_string, main_string, definition;
var category;
$(document).ready( function() {
	pre_string = \"\";
	main_string = \"\";
	definition = \"\";
	category = \"none\";
	
	$(\"button\").button();
"	

# Submit button
scriptcode += "
	$(\"#button_submit\").click( function (){

		var query = pre_string + \" \" + main_string;
		$.post(\"http://localhost:4567/word\",
		{
			\"query\":query
		},
		function(data, status) {
			$(\"#output\").html(\"<h1>\" + $.trim(data) + \"</h1> (\" + category[0] + \".)\");
			
		}).error( function(jqXHR, textStatus, errorThrown){
			alert(textStatus + \" - \" + errorThrown);
		});
		
		$(\"select\").val(\"null\");
	});
"
# Clear button
scriptcode += "
	$(\"#button_clear\").click( function() {

		pre_string = \"\";
		main_string = \"\";
		category = \"none\";
		definition = \"\";
		$(\"#elements_list\").css(\"display\", \"none\");
		$(\"#elements_list\").html(\"\");
		$(\"#definition\").html(\"\");
		$(\"#output\").html(\"\");
		$(\"#button_submit\").attr(\"disabled\",\"disabled\");
		$(\"select\").val(\"null\");
		
		change_category(\"none\");
	});
"

# Add word token buttons
dropmenu["latin"]["word"].each do |i|
	if i.name == "preposition"
	scriptcode += "
	$(\"#button_#{i.name}\").click( function() {
			category = \"#{i.name}\";
			value = $(\"#menu_#{i.name}\").val();
			
			if (value == null) return;

			if (pre_string != \"\"){
				pre_string = pre_string + \" \";
			}
			if (definition != \"\"){
				definition = \" \" + definition;
			}
			
			pre_string = pre_string + value;
			definition = $(\"#menu_#{i.name} option:selected\").text() + definition;
			
			update();
	});\n"
	else
	scriptcode += "
	$(\"#button_#{i.name}\").click( function() {
			category = \"#{i.name}\";
			value = $(\"#menu_#{i.name}\").val();

			if (value == null) return;
			
			if (main_string != \"\"){
				main_string += \" \";
			}
			if (definition != \"\"){
				definition += \" \";
			}

			main_string += value;
			definition += $(\"#menu_#{i.name} option:selected\").text();

			update();
			change_category(category);
	});\n"
	end
end

# Add suffix token buttons
dropmenu["latin"]["affix"].each do |k, v|
	v.each do |k2, v2|
		scriptcode += "
	$(\"#button_#{v2.name}\").click( function() {
		category = \"#{k2}\";
		value = $(\"#menu_#{v2.name}\").val();
		
		if (value == null) return;
		
		if (main_string != \"\"){
			main_string += \" \";
		}
		if (definition != \"\"){
			definition = \" \" + definition;
		}
			
		main_string += value;
		definition = $(\"#menu_#{v2.name} option:selected\").text() + definition;
		
		update();
		change_category(category);
	});\n"
	end
end

scriptcode += 
"});"

# Helper functions
scriptcode += "

function change_category(newcat){
	$(\".affixdiv\").each( function() {
		var split = $(this).attr(\"id\").split(\"_\");
		if(split[0] == $(\"#menu_language\").val() &&
			split[1] == newcat) {
			$(this).css(\"display\", \"block\");
		} else {
			$(this).css(\"display\", \"none\");
		}
	});
}

function update(){
	$(\"#definition\").text(definition);
	if (main_string != \"\")
		$(\"#button_submit\").button(\"option\", \"disabled\", false);
	var total = \"\";
	
	$(\"#elements_list\").html(\"\");
	if(pre_string != \"\") total += pre_string;
	if(pre_string != \"\" && main_string != \"\") total += \" \";
	if(main_string != \"\") total += main_string;
	var words = total.split(\" \");
	for (var i = 0; i < words.length; ++i){
		$(\"#elements_list\").append(\"<span class=\\\"elementtile\\\">\" + words[i] + \"</span>\");
	}
	$(\"#elements_list\").css(\"display\", \"block\");
}

</script>"

f.write(scriptcode)

# Add the tail =====================
tail = "
</body>\n
</html>\n
";
f.write(tail)
