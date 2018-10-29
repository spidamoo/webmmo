
let world_container;

function init_game(canvas_id) {
    world_container = new PIXI.Container();
    app.stage.addChild(world_container);

    init_ships_graphics();
    init_effects_graphics();
    init_interface();
    init_network();
}

function update_game(dt) {
    if (my_ship) {
        world_container.x = 400 - my_ship.data.x;
        world_container.y = 300 - my_ship.data.y;
    }
    update_ships(dt);
    update_effects(dt);
}

function process_message(data) {
    console.log('receive', data);
    switch(data.type) {
        case 'id':
            my_id = data.id;
        break;
        case 'zone':
            move_zone(data);
        break;
        case 'ships':
            add_ships(data);
            my_ship = ships['player_' + my_id];
            if (my_ship.data.docked) {
                dock();
            }
            else {
                undock();
            }
        break;
        case 'effects':
            add_effects(data);
        break;
        case 'ship_destroyed':
            ships[data.id].destroy();
        break;
        case 'effect_destroyed':
            effects[data.id].destroy();
        break;
        case 'objects':
            replace_objects(data.objects);
            draw_objects();
        break;
        case 'inventory':
            update_inventory(data.items);
        break;
        case 'equip':
            update_equip(data.slots);
        break;
        case 'skills':
            update_skills(data.skills);
            skills = data.skills;
        break;
        case 'schemas':
            update_schemas(data.schemas);
            $craft_window.show();
        break;
    }
}

function dock() {
    control_allowed = false;
    $equip_window.unfreeze();
}

function undock() {
    control_allowed = true;
    $craft_window.hide();
    $equip_window.freeze();
}

function craft(index) {
    send_msg({type: 'craft', what: index});
}
function use(index) {
    send_msg({type: 'use', what: index});
}
function unequip(index) {
    send_msg({type: 'unequip', what: index});
}

function use_skill(index, params) {
    if (!skills[index]) {
        return;
    }
    send_msg({type: 'skill', what: index, params: params});
}
