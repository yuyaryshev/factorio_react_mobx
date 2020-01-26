const cheerio = require("./extend_cherrio");

function toArray(a) {
    const r = [];
    const n = a.length;
    for (let i = 0; i < n; i++) r.push(a[i]);
    return r;
}

function parse_factorio_ui_api(html) {
    const $ = cheerio.load(html);
    const r = {
        widgets: {},
        funcs: {},
        props: {},
        common_props: {},
        prop_types:{},
    };

    const widgets = $(".brief-description > ul > li")
        .toArray()
        .map(item => {
            const [name, description] = $(item)
                .text()
                .split(/[\"\:]/g)
                .map(s => s.trim())
                .filter(s => s.length);
            r.widgets[name] = {
                t: "widget",
                name,
                description,
                props: {},
                specific_props: {},
            };
        });
    const members = $("table.brief-members > tbody > tr")
        .toArray()
        .map(item => {
            const [c0, description] = $(item)
                .children()
                .toArray()
                .map(item =>
                    $(item)
                        .text()
                        .trim(),
                );
            if (c0.includes("(")) {
                const r0 = c0
                    .split(/[\(\)\,]+/g)
                    .map(s => s.trim())
                    .filter(s => s.length);
                const type = r0.pop();
                const [name, ...params] = r0;
                r.funcs[name] = {
                    t: "function",
                    name,
                    params,
                    type,
                    description,
                };
            } else {
                const [name, type, accessors] = c0
                    .split(/[\:\[\]\"]+/g)
                    .map(s => s.trim())
                    .filter(s => s.length);
                r.props[name] = {
                    t: "property",
                    name,
                    type,
                    accessors,
                    description,
                };
            }
        });

    $("div#LuaGuiElement\\.add > div > div > div > div > ul > li")
        .toArray()
        .map(s => {
            const text = $(s)
                .text()
                .trim();
            if (text.startsWith("Other")) {
                $(s)
                    .children("ul")
                    .children("li")
                    .toArray()
                    .map(w => {
                        const widgetName = $(w).this_text();
                        const props = $(w)
                            .children("ul")
                            .children("li")
                            .toArray()
                            .map(c => {
                                const name = $(".param-name", c).full_text();
                                const type = $(".param-type", c).full_text();
                                const opt = !!$(".opt", c).full_text().length;
                                const description = $(w).this_text();
                                if (!r.widgets[widgetName])
                                    console.log(`CODE00000000 widget '${widgetName}' not found!`)
                                else
                                    r.widgets[widgetName].specific_props[
                                        name
                                    ] = {
                                        name,
                                        type,
                                        opt,
                                        description,
                                        specific: true,
                                    };
                            });
                    });
            } else {
                const [name, type0, description] = text
                    .split(/[\:\[\]\"]+/g)
                    .map(s => s.trim())
                    .filter(s => s.length);
                const [type, optional] = type0
                    .split(/[\(\)]+/g)
                    .map(s => s.trim())
                    .filter(s => s.length);
                r.common_props[name] = {
                    t: "param",
                    name,
                    type,
                    optional: !!(optional && optional.length),
                    description,
                    specific: false,
                };
            }
        });

    for (let w of Object.values(r.widgets)) {
        w.props = { ...r.common_props, ...w.specific_props };
        for(let p in w.props) {
            const wprop =                 w.props[p];
            const rprop = r.props[p];
            if(!rprop) {
                console.error(`CODE00000000 ${w.name}.${p} not found in r.props! Readonly attribute for this prop might be incorrect!`);
                wprop.accessors = "R";
            }
            else {
                wprop.accessors = rprop.accessors;
                wprop.type = rprop.type;

                // if(wprop.description !== rprop.description)
                //     console.warn(`CODE00000000 wprop.description '${wprop.description}' !== rprop.description '${rprop.description}'`);
                wprop.r_description = rprop.description;
            }
        }
    }

    const prop_types_map = {};
    Object.values(r.widgets).map(w => Object.values(w.props).map(prop => r.prop_types[prop.type] = (r.prop_types[prop.type] || 0) + 1));
    return r;
}

module.exports = {parse_factorio_ui_api};

//console.log(JSON.stringify(parse_factorio_ui_api(require("fs").readFileSync("response.html")), undefined, "    "));
// console.log(JSON.stringify(parse_factorio_ui_api(require("fs").readFileSync("response.html")), undefined, "    "));
//console.log(JSON.stringify(parse_factorio_ui_api(require("fs").readFileSync("response.html")).prop_types, undefined, "    "));
