var control = {};
var control_allowed = true;
var my_id;

function init_control() {
    console.log('init_control');
    control = {
        right:  false,
        left:   false,
        up:     false,
        down:   false,
        move:   0,
    };

    document.onkeydown = function(event) {
        switch (event.code) {
            case 'ArrowUp':
                control.up = true;
            break;
            case 'ArrowDown':
                control.down = true;
            break;
            case 'ArrowLeft':
                control.left = true;
            break;
            case 'ArrowRight':
                control.right = true;
            break;
            case 'Space':
                for (var id in ships) {
                    var ship = ships[id];
                    if (ship.type != 'station') {
                        continue;
                    }
                    var my_ship = ships['player_' + my_id];
                    var dx = my_ship.x - ship.x;
                    var dy = my_ship.y - ship.y;
                    var distance = Math.sqrt( Math.pow(dx, 2) + Math.pow(dy, 2) );
                    if (distance > 100) {
                        continue;
                    }
                    send_msg({type: 'dock', to: id});
                    break;
                };
            break;
        }
        update_control();
    }
    document.onkeyup = function(event) {
        switch (event.code) {
            case 'ArrowUp':
                control.up = false;
            break;
            case 'ArrowDown':
                control.down = false;
            break;
            case 'ArrowLeft':
                control.left = false;
            break;
            case 'ArrowRight':
                control.right = false;
            break;
        }
        update_control();
    }
}

function update_control(dt) {
    if (zone_type == 'space') {
        update_ship_control(dt);
    }
}
function update_ship_control(dt) {
    if (control_allowed) {
        var old_move = control.move;

        if (control.right) {
            if (control.up) {
                control.move = [% Game::MOVE_RU %];
            }
            else if (control.down) {
                control.move = [% Game::MOVE_RD %];
            }
            else {
                control.move = [% Game::MOVE_R %];
            }
        }
        else if (control.left) {
            if (control.up) {
                control.move = [% Game::MOVE_LU %];
            }
            else if (control.down) {
                control.move = [% Game::MOVE_LD %];
            }
            else {
                control.move = [% Game::MOVE_L %];
            }
        }
        else if (control.up) {
            control.move = [% Game::MOVE_U %];
        }
        else if (control.down) {
            control.move = [% Game::MOVE_D %];
        }
        else {
            control.move = [% Game::MOVE_IDLE %];
        }

        if (old_move != control.move) {
            send_msg({type: 'move', 'move': control.move});
        }
    }
}