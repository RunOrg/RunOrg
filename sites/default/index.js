// Default controller

Route.add(/^[^#]*$/, function(R) {
    R.layout();
    R.show();
});
