/* Authenticating with Persona.
 * 
 * Initially, the user is not authenticated. After login, function onLogin is called
 * by this file with the token.
 */

$('#persona-button')[0].onclick = function() {

    navigator.id.get(function(assertion){
	
	console.log("Received assertion: %s", assertion);
	API.AUTH('/admin/auth/persona', {assertion:assertion}, function(r){
	    console.log("Assertion verified: %o", r);
	    onLogin();
	});
	
    },{
	siteName: 'RunOrg Server Administration',
	siteLogo: 'https://' + document.location.host + '/admin/logo.png'
    });
    
};