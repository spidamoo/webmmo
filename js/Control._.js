let control = {};
let control_allowed = true;
let skills = [];

let my_id;
let my_ship;

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
                if (!my_ship.data.docked) {
                    for (let id in ships) {
                        const ship = ships[id];
                        if (ship.data.type != 'station') {
                            continue;
                        }
                        const dx = my_ship.data.x - ship.data.x;
                        const dy = my_ship.data.y - ship.data.y;
                        const distance = Math.sqrt( Math.pow(dx, 2) + Math.pow(dy, 2) );
                        if (distance > 100) {
                            continue;
                        }

                        send_msg({type: 'dock', to: id});
                        break;
                    };
                }
                else {
                    send_msg({type: 'undock'});
                }
            break;
        }
        update_control();

        event.preventDefault();
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

        event.preventDefault();
    }
    app.view.onclick = function(event) {
        let angle = Math.atan2(event.offsetY - my_ship.data.y, event.offsetX - my_ship.data.x);
        use_skill(0, {a: angle});
    }
}

function update_control(dt) {
    if (control_allowed) {
        let old_move = control.move;

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
