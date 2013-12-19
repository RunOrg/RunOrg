/* Internationalization object */

function i18n(obj) {
    for (var key in obj) {
	var segs = key.split("."), root = i18n;
	for (var i = 0; i < segs.length - 1; ++i) 
	    root = (root[i] = root[i] || {});
	root[segs.length-1] = obj[key];
    }
}

i18n.clear = function() {
    for (var key in i18n) 
	if (i18n.hasOwnProperty(key) && key != 'clear')
	    delete i18n[key];
};
