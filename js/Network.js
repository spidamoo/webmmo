var socket;

function init_network() {
    const ws_path = "ws://" + window.location.host + "/_hippie/ws";
    socket = new WebSocket(ws_path);
    socket.onopen = function() {
        $('#connection-status').text("Connected");
    };
    socket.onerror = function() {
        $('#connection-status').text("Error");
    }
    socket.onclose = function() {
        $('#connection-status').text("Disconnected");
    }
    socket.onmessage = function(e) {
        const data = JSON.parse(e.data);
        console.log(e.data, data, control);
        switch(data.type) {
            case 'id':
                my_id = data.id;
            break;
            case 'zone':
                move_zone(data);
            break;
            case 'ships':
                add_ships(data);
            break;
            case 'ship_destroyed':
                ships[data.id].destroy();
            break;
            case 'objects':
                replace_objects(data.objects);
                draw_objects();
            break;
        }
    };
}
 
function send_msg(message) {
    console.log('send', message);
    socket.send( JSON.stringify(message) );
}
