// JSON <template>
// Types / Template
//
// Templates describe how RunOrg should generate text or HTML from input data.
//
// For example, a template can be used to generate include the contact's name
// in [the body of an e-mail](/docs/#/mail/create.js) sent to multiple 
// contacts. 
//
// ### Template JSON format
//     { "script" : <string>, 
//       "inline" : [ <json>, ... ] }
//
// A template specifies two elements: a script in the RunOrg-specific template 
// programming language, and an array of values to be used by the script. 
//
// When RunOrg uses a template, it fetches the required data (both the t
// emplate's `inline` block and contextual information like the contact who 
// will receive the mail) and executes the script (a list of output 
// statements separated by semicolons)
// 
// # Basic example
//
// Consider the template which would say `Hello, Marcus !` using the first name
// `Victor` as an input: 
//
// ### Example template and data 
//
//     // template
//     { "script" : "$0;to.firstname;$1", 
//       "inline" : [ "Hello, ", " !" ] }
//
//     // context data 
//     { "to" : { 
//         "firstname" : "Marcus", 
//         "lastname": "Cato",
//         "fullname" : "Marcus Porcius Cato" },
//       "from" : {
//         "firstname" : "Hannibal", 
//         "fullname" : "Hannibal, son of Hamilcar Barca" } }
//
// # Syntax reference
// 
// - `$0`, `$1`, `$n` are replaced by the corresponding value in the `inline`
//   array. `$0` is the first cell. 
// - `foo` references value `foo` in the context provided by RunOrg. The context
//   is entirely dependent on how the template is used, so refer to the specific
//   documentation of that use to know what the context will be. 
// - `expr.member` is member access, in the JavaScript sense. 
// - `expr[i]` is array access, in the JavaScript sense. The index must be a 
//   constant. 
// - `;` is a separator between values that will be output. 
// 
// # HTML output
// 
// When templates are used to generate HTML, some values will be escaped while 
// others will not. The exact rule is:
// 
//  - String values that are directly taken out of the `inline` array are not
//    escaped.
//  - Anything else is escaped. 
// 
// So `$0` will not be escaped, but `$1[3]` or `$2.name` will be. 
//
// ### HTML template example
//
//     // template 
//     { "script" : "$0;to.firstname;$1",
//       "inline" : [ "Hello, <b>", "</b> !" ] }
//  
//     // data
//     { "to" : {
//         "firstname": "EVIL <script>..." } }
//
//     // output
//     Hello, <b>EVIL &lt;script&gt;...</b> !

TEST("Text-based template.", function(next){

    var data = {
	script: "$0;to.firstname;$1",
	inline: [ "Hello, ", " !" ],
	input : { "to": { "firstname": "Victor&", "lastname": "Nicollet" } },
	html  : false
    };

    var result = Test.query("POST","/test/unturing",data).result("result");
    Assert.areEqual("Hello, Victor& !", result).then(next);

});

TEST("HTML-based template.", function(next){

    var data = {
	script: "$0;to.firstname;$1",
	inline: [ "Hello, <b>", "</b> !" ],
	input : { "to": { "firstname": "Victor&", "lastname": "Nicollet" } },
	html  : true
    };

    var result = Test.query("POST","/test/unturing",data).result("result");
    Assert.areEqual("Hello, <b>Victor&amp;</b> !", result).then(next);

});
