
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
        this.container = new PIXI.Container();

        switch (this.data.type) {
            case 'station':
                this.shape = new PIXI.Graphics();
                this.shape.lineStyle(1, 0xFFFFFF);
                this.shape.beginFill(0xADD8E6).drawCircle(0, 0, 100).endFill();
                this.shape.lineStyle(1, 0xFFFFFF);
                this.shape.beginFill(0x696969).drawCircle(80, 0, 18).endFill();

                this.container.addChild(this.shape);
            break;
            case 'monster':
                console.log(this.data, PIXI.loader.resources);
                this.shape = new PIXI.Sprite(PIXI.loader.resources['monster:' + this.data.codename].texture);
                this.shape.anchor.x = 0.5;
                this.shape.anchor.y = 0.5;

                this.container.addChild(this.shape);
            break;
            default:
                this.shape = new PIXI.Graphics();
                this.shape.lineStyle(1, 0xFFFFFF);
                this.shape.beginFill(0xd3d3d3).drawPolygon([10, 0, -10, -5, -10, 5]).closePath().endFill();

                this.container.addChild(this.shape);
        }

        console.log('draw ship', this);

        this.container.visible = false;
        const container = this.data.type == 'station' ? stations_container : ships_container;
        container.addChild(this.container);

        if (this.data.max_hp) {
            this.draw_hp();
        }
    }

    draw_hp() {
        if (!this.hp_graphics) {
            this.hp_graphics = new PIXI.Graphics();
            this.hp_graphics.y = 20;
            this.container.addChild(this.hp_graphics);
        }
        this.hp_graphics.clear();
        for (let i = 0; i < this.data.max_hp; i++) {
            const x = i * 5 - this.data.max_hp * 2.5;
            if (this.data.hp > i) {
                this.hp_graphics.lineStyle(1, 0xFFFFFF).beginFill(0x00FF00).drawRect(x, 0, 5, 5).endFill();
            }
            else {
                this.hp_graphics.lineStyle(1, 0xFFFFFF).beginFill(0x000000).drawRect(x, 0, 5, 5).endFill();
            }
        }
    }

    update(dt) {
        this.container.visible = true;

        // console.log('update ship', this);

        if (dt) {
            this.data.x += this.data.dx * dt;
            this.data.y += this.data.dy * dt;
            if (this.data.da !== null) {
                this.data.a += this.data.da * dt;
            }
        }

        this.container.x        = this.data.x;
        this.container.y        = this.data.y;
        if (this.data.a !== null) {
            this.shape.rotation = this.data.a;
        }
        else {
            this.shape.rotation = (this.data.direction - 1) * Math.PI * 0.25 ;
        }
    }
    update_data(data) {
        this.data = data;
        this.draw_hp();
    }

    destroy() {
        const container = this.data.type == 'station' ? stations_container : ships_container;
        container.removeChild(this.container);
        delete ships[this.id];
    }
}
