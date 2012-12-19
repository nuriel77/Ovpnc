/* Global functions */
function ucfirst(str) {
    var f = str.chrAt(0).toUpperCase();
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

