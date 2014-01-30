/* Parsing test sets */
function parseTestFixture(script) {

    var parsed = { tests: [], status: null, version: null };

    // The test functions themselves
    var run = eval("(function(TEST){\n" + script + "\n})")(function(name,run){
	parsed.tests.push({name : name, run: run});
    });

    // The lines that are commented (the test fixture test)
    var lines = script.split("\n");
    var text  = [];
    for (var i = 0; i < lines.length; ++i) 
	if (/^\s*\/\//.exec(lines[i])) 
	    text.push(lines[i].replace(/^\s*\/\/\s?/,''));	    

    parsed.query = text.shift();
    parsed.description = text.shift().replace(/^.*\/\s*/,'');   

    while (text[0].trim() == '') text.shift();

    if (/@/.exec(text[0])) {
	var current = text.shift().split('@');
	parsed.status = current[0].trim();
	parsed.version = current[1].trim();
    }

    parsed.body = markdown.toHTML(text.join('\n').trim());

    return parsed;
}
