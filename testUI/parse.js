/* Parsing test sets */
function parseTestFixture(script) {

    var parsed = { tests: [] };

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

    parsed.body = markdown.toHTML(text.join('\n').trim());

    return parsed;
}
