
let ships = {};
let ships_container;
let stations_container;

function init_ships_graphics() {
    ships_container    = new PIXI.Container();
    stations_container = new PIXI.Container();

    world_container.addChild(stations_container);
    world_container.addChild(ships_container);
}

function add_ships(data) {
    if (data.replace) {
        clear_ships();
    }

    Object.entries(data.ships).forEach(function(s) {
        const [id, ship_data] = s;
        if (ships[id]) {
            ships[id].update_data(ship_data);
        }
        else {
            ships[id] = new Ship(id, ship_data);
        }
    });
}

function clear_ships() {
    console.log('clear_ships');
    Object.values(ships).forEach(function(ship) {
        ship.destroy();
    });
    ships = {};
}

function update_ships(dt) {
    Object.entries(ships).forEach(function(o) {
        [id, ship] = o;

        ship.update(dt);
    });
}


class Ship {
    constructor(id, data) {
        this.id = id;
        this.data = data;
        this.draw();
    }
    draw() {
        this.graphics = new PIXI.Graphics();

        switch (this.data.type) {
            case 'station':
                this.graphics.lineStyle(1, 0xFFFFFF);
                this.graphics.beginFill(0xADD8E6).drawCircle(0, 0, 100).endFill();
                this.graphics.lineStyle(1, 0xFFFFFF);
                this.graphics.beginFill(0x696969).drawCircle(80, 0, 18).endFill();
            break;
            case 'monster':
                console.log(this.data, PIXI.loader.resources);
                this.graphics = new PIXI.Sprite(PIXI.loader.resources['monster:' + this.data.codename].texture);
                this.graphics.anchor.x = 0.5;
                this.graphics.anchor.y = 0.5;
            break;
            default:
                this.graphics.lineStyle(1, 0xFFFFFF);
                this.graphics.beginFill(0xd3d3d3).drawPolygon([10, 0, -10, -5, -10, 5]).closePath().endFill();
        }

        console.log('draw ship', this);

        this.graphics.visible = false;
        const container = this.data.type == 'station' ? stations_container : ships_container;
        container.addChild(this.graphics);
    }

    update(dt) {
        this.graphics.visible = true;

        // console.log('update ship', this);

        if (dt) {
            this.data.x += this.data.dx * dt;
            this.data.y += this.data.dy * dt;
            if (this.data.da !== null) {
                this.data.a += this.data.da * dt;
            }
        }

        this.graphics.x        = this.data.x;
        this.graphics.y        = this.data.y;
        if (this.data.a !== null) {
            this.graphics.rotation = this.data.a;
        }
        else {
            this.graphics.rotation = (this.data.direction - 1) * Math.PI * 0.25 ;
        }
    }
    update_data(data) {
        this.data = data;
    }

    destroy() {
        const container = this.data.type == 'station' ? stations_container : ships_container;
        container.removeChild(this.graphics);
        delete ships[this.id];
    }
}
