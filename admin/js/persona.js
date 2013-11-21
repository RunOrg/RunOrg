/* Authenticating with Persona.
 * 
 * Initially, the user is not authenticated. After login, function onLogin is called
 * by this file with the token.
 */

$('#persona-button')[0].onclick = function() {

    navigator.id.get(function(assertion){
	
	console.log("Received assertion: %s", assertion);
	$.ajax({
	    method: 'POST',
	    contentType: 'application/json',
	    url: '/admin/auth/persona',
	    data: JSON.stringify({assertion:assertion}),
	    success: function(r){
		console.log("Assertion verified: %o", r);
		onLogin(r.token);
	    }
	});
	
    },{
	siteName: 'RunOrg Server Administration',
	siteLogo: 'https://' + document.location.host + '/admin/logo.png'
    });
    
};