/* Global functions */
function ucfirst(str) {
    var f = str.charAt(0).toUpperCase();
    return f + str.substr(1);
}

function get_date() {
    var now = new Date();
    var hrs = now.getHours();
    var min = now.getMinutes();
    var sec = now.getSeconds();
    var then = now.getDay() + '-'
             + (now.getMonth() + 1) + '-'
             + now.getFullYear() + ' '
             + ( hrs < 10 ? '0' + hrs : hrs ) + ':'
             + ( min < 10 ? '0' + min : min ) + ':'
             + ( sec < 10 ? '0' + sec : sec );

    return then;
}

function get_time() {
    var now = new Date();
    var hrs = now.getHours();
    var min = now.getMinutes();
    var sec = now.getSeconds();
    var then = ( hrs < 10 ? '0' + hrs : hrs ) + ':'
             + ( min < 10 ? '0' + min : min ) + ':'
             + ( sec < 10 ? '0' + sec : sec );
    return then;
}

function numberWithCommas(n) {
    var parts = n.toString().split(".");
    return parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",") + (parts[1] ? "." + parts[1] : "");
}

function fnSelect(objId) {
    fnDeSelect();
    if (document.selection) {
    var range = document.body.createTextRange();
        range.moveToElementText(document.getElementById(objId));
    range.select();
    }
    else if (window.getSelection) {
    var range = document.createRange();
    range.selectNode(document.getElementById(objId));
    window.getSelection().addRange(range);
    }
}

function fnDeSelect() {
    if (document.selection) document.selection.empty();
    else if (window.getSelection)
            window.getSelection().removeAllRanges();
}

function checkPendingRequest() {
    // Check for pending ajax calls
    if ($.active > 0) {
        //log( $.active + " ajax call(s) still active");
        //window.setTimeout(checkPendingRequest, 1000); // run again
        return true;
    }
    return false;
}

function NASort(a, b) {
    if (a.innerHTML == 'NA') {
        return 1;
    }
    else if (b.innerHTML == 'NA') {
        return -1;
    }
    return (a.innerHTML > b.innerHTML) ? 1 : -1;
};

function getURLParameter(sParam){
    var sPageURL = window.location.search.substring(1);
    var sURLVariables = sPageURL.split('&');
    for (var i = 0; i < sURLVariables.length; i++){
        var sParameterName = sURLVariables[i].split('=');
        if (sParameterName[0] == sParam){
            return sParameterName[1];
        }
    }
}
