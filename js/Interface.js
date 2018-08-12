
let $inventory_window;
let $craft_window;
let $equip_window;
let $skills_window;

function init_interface() {
    $('body').append( create_inventory_window() );
    $('body').append( create_equip_window().addClass('frozen') );
    $('body').append( create_skills_window() );
    $('body').append( create_craft_window().hide() );

    $('body').append( create_status_bar() );
}

function create_inventory_window() {
    $inventory_window = create_window('Cargo', 'inventory_window');
    $inventory_window.append( create_inventory_table(4, 4) );
    return $inventory_window;
}

function create_craft_window() {
    $craft_window = create_window('Craft');
    $craft_window.append('<div id="schemas"></div>')
    return $craft_window;
}

function create_equip_window() {
    $equip_window = create_window('Equip');
    $equip_window.append('<div id="equip">&nbsp;</div>')
    return $equip_window;
}

function create_skills_window() {
    $skills_window = create_window('Skills');
    $skills_window.append('<div id="skills">&nbsp;</div>')
    return $skills_window;
}

function create_window(title, id) {
    if (id === undefined) {
        id = title.toLowerCase() + '_window';
    }
    return $('<div id="' + id + '" class="window"><div class="title">' + title + '</div></div>');
}

function create_inventory_table(cols, rows) {
    const $table = $('<table></table>');
    for (let i = 0; i < rows; i++) {
        $table.append('<tr></tr>');
    }
    for (let i = 0; i < cols; i++) {
        $table.find('tr').append('<td></td>');
    }

    return $table;
}

function create_status_bar() {
    return $('<div id="connection_status_div" class="window"><span id="connection_status">Disconnected</span></div>');
}

function update_inventory(items) {
    const $table = $('#inventory_window table');
    for (let i in items) {
        const item = items[i];
        const $td = $table.find('td').eq(i);
        $td.empty();
        if (item) {
            const $item_div = item_div(item);
            $item_div.click(function() {
                use(i);
            });
            $td.append($item_div);
        }
    }
}

function update_equip(slots) {
    const $div = $('#equip');
    $div.empty();

    for (let i in slots) {
        const slot = slots[i];
        const $slot_div = $('<div class="slot ' + slot.type + '"></div>');
        if (slot.equipped) {
            const $item_div = item_div(slot.equipped);
            $item_div.click(function() {
                if ( $equip_window.frozen() ) {
                    return;
                }
                unequip(i);
            });
            $slot_div.html($item_div);
        }
        else {
            $slot_div.html('?');
        }
        $div.append($slot_div);
    }
}

function update_skills(skills) {
    const $div = $('#skills');
    $div.empty();

    for (let i in skills) {
        const skill = skills[i];
        const $skill_div = $('<div class="skill"></div>');
        if (skill) {
            $skill_div.html('<img src="/img/skills/' + skill.codename + '.png"/>');
        }
        else {
            $skill_div.html('?');
        }
        $div.append($skill_div);
    }
}

function update_schemas(schemas) {
    $('#schemas').empty();

    for (let i in schemas) {
        const $div = $('<div class="schema"></div>');

        for (let j in schemas[i].materials) {
            $div.append( item_div(schemas[i].materials[j]) );
        }
        const item = schemas[i].result;
        $div.append('<div class="schema_result_delimiter">&gt;</div>')
        $div.append( item_div(schemas[i].result) );

        $div.click(function() {
            craft(i);
        });

        $('#schemas').append($div);
    }
}

function item_div(item) {
    return $('<div class="item"><img src="/img/items/' + item.codename + '.png"/><span class="number">' + item.number + '</span></div>');
}


$(function() {
    $.fn.freeze = function() {
        $(this).addClass('frozen');
    }
    $.fn.unfreeze = function() {
        $(this).removeClass('frozen');
    }
    $.fn.frozen = function() {
        return $(this).hasClass('frozen');
    }
});
