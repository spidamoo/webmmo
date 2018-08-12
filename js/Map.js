
const objects = [];
let zone_type = 'space';

function move_zone(data) {
    console.log('move_zone');
    clear_ships();
    clear_objects();

    init_control();
}

function clear_objects() {
    while (objects.length) {
        objects.shift().destroy();
    }
}

function replace_objects(data) {
    clear_objects();
}

function draw_objects() {
}

class MapObject {
    constructor() {
    }
    destroy() {

    }
}
