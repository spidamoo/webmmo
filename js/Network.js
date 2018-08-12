let socket;

function init_network() {
    const ws_path = "ws://" + window.location.host + "/_hippie/ws";
    socket = new WebSocket(ws_path);
    socket.onopen = function() {
        $('#connection_status').text("Connected").attr('class', 'connected');
    };
    socket.onerror = function() {
        $('#connection_status').text("Error").attr('class', 'disconnected');
    }
    socket.onclose = function() {
        $('#connection_status').text("Disconnected").attr('class', 'disconnected');
    }
    socket.onmessage = function(e) {
        const data = JSON.parse(e.data);
        process_message(data);
    };
}
 
function send_msg(message) {
    console.log('send', message);
    socket.send( JSON.stringify(message) );
}
