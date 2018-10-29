
let effects = {};
let effects_container;

function init_effects_graphics() {
    effects_container    = new PIXI.Container();

    world_container.addChild(effects_container);
}

function add_effects(data) {
    if (data.replace) {
        clear_effects();
    }

    Object.entries(data.effects).forEach(function(s) {
        const [id, effect_data] = s;
        effects[id] = new Effect(id, effect_data);
    });
}
function remove_effect(effect) {
    effect.destroy();
    effects[effect.id] = undefined;
}
function clear_effects() {
    console.log('clear_effects');
    Object.values(effects).forEach(function(effect) {
        effect.destroy();
    });
    effects = {};
}

function update_effects(dt) {
    Object.entries(effects).forEach(function(o) {
        [id, effect] = o;
        if (!effect) {
            return;
        }
        effect.update(dt);
    });
}


class Effect {
    constructor(id, data) {
        this.id = id;
        this.data = data;

        switch (data.codename) {
            case 'shot':
                this.ttl = 1;
            break;
        }

        this.draw();
    }
    draw() {
        this.graphics = new PIXI.Graphics();

        switch (this.data.codename) {
            case 'shot':
                this.graphics.lineStyle(1, 0xFF0000);
                this.graphics.beginFill(0xFF0000).drawCircle(0, 0, 3).endFill();
            break;
            default:
                this.graphics.lineStyle(1, 0xFF0000);
                this.graphics.beginFill(0xFF0000).drawCircle(0, 0, 5).endFill();
        }

        this.graphics.visible = false;
        effects_container.addChild(this.graphics);
    }

    update(dt) {
        this.graphics.visible = true;

        if (dt) {
            this.data.x += this.data.dx * dt;
            this.data.y += this.data.dy * dt;
            if (this.data.da !== null) {
                this.data.a += this.data.da * dt;
            }

            if (this.ttl !== undefined) {
                this.ttl -= dt;
                if (this.ttl < 0) {
                    remove_effect(this);
                    return;
                }
            }
        }

        this.graphics.x        = this.data.x;
        this.graphics.y        = this.data.y;
        if (this.data.a !== null) {
            this.graphics.rotation = this.data.a;
        }
    }
    update_data(data) {
        this.data = data;
    }

    destroy() {
        effects_container.removeChild(this.graphics);
        delete effects[this.id];
    }
}
