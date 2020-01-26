const { jsObjectToLua } = require("json_to_lua");
const { resolve } = require("path");
const { readFileSync, writeFileSync } = require("fs");
const axios = require("axios");
const { parse_factorio_ui_api } = require("./parse");

const html = readFileSync("response.html");
const ui_api_meta = parse_factorio_ui_api(html);

console.log(JSON.stringify(ui_api_meta.prop_types, undefined, "    "));

function quot_prop(p) {
    return p.split(/[-]+/g).length > 1 ? `["${p}"]` : p;
}

function quot_prop2(p) {
    const r = quot_prop(p);
    return r[0] === "[" ? r : "." + r;
}

function getPropType(prop) {
    switch (prop.type) {
        case "string":
        case "boolean":
        case "double":
        case "uint":
            return {
                categoty: "primitive",
                isPrimitive: true,
                isPrimitiveLike: true,
                isObject: false,
            };
    }
    switch (prop.type) {
        case "LocalisedString":
        case "MouseButtonFlags":
        case "SpritePath":
        case "SignalID":
        case "LuaStyle or string":
            return {
                categoty: "primitiveLike",
                isPrimitive: false,
                isPrimitiveLike: true,
                isObject: false,
            };
    }

    switch (prop.type) {
        case "array of LocalisedStringLocalisedString":
        case "array of LocalisedString":
        case "LuaEntity":
        case "Position":
            return {
                categoty: "object",
                isPrimitive: false,
                isPrimitiveLike: false,
                isObject: true,
            };
    }

    console.trace(
        `CODE00000000 function getPropType doesn't know type='${prop.type}'!`,
    );
    return {
        categoty: "object",
        isPrimitive: false,
        isPrimitiveLike: false,
        isObject: true,
    };
}

function propCompile(prop) {
    const propType = getPropType(prop);
    const fname = quot_prop(prop.name);
    const pname = quot_prop2(prop.name);

    return Object.assign(prop, propType, {
        not_equal: propType.isPrimitiveLike
            ? ` n${pname} ~= o${pname} `
            : ` not deep_equal(n${pname}, o.${pname}) `,
        readonly: !prop.accessors.includes("W"),
        fname,
        pname,
    });
}

function neq(prop) {
    return propType(prop).isPrimitiveLike
        ? ` n.${prop.name} ~= o.${prop.name} `
        : ` not deep_equal(n${prop.name}, o.${prop.name}) `;
}

// require("deep_equal");

const generatedContent = `
update_ui_funcs = {
${Object.values(ui_api_meta.widgets)
    .map(w => {
        const props = Object.values(w.props);
        props.map(propCompile);

        const props_not_equal = props
            .map(prop => `or ${prop.not_equal}`)
            .join("\n");

        return `${quot_prop(w.name)} = function(ui_parent, n, o)
-- If one of readonly attrs changed -> recreate, else -> update props
    if not o 
        or not n.ui
        ${props
            .filter(p => p.readonly)
            .map(p => `or ${p.not_equal}`)
            .join("\n        ")}
    then
        -- Recreate ui
        if o and o.ui then
            o.ui.destroy()
            o.children = nil 
        end
        n.ui = ui_parent.add{	
            ${props
                .filter(p => true)
                .map(p => `${p.fname} = n${p.pname}`)
                .join(",\n            ")}
        }
    else
        n.ui = o.ui
    -- Update props
        ${props
            .filter(p => !p.readonly)
            .map(
                p =>
                    `if ${p.not_equal.trim()} then n.ui${p.pname} = n${
                        p.pname
                    } end`,
            )
            .join("\n        ")}
    end
end`;
    })
    .join(`,\n\n`)}
}
`;

let settings = { copyToPath: [] };
try {
    const settingsStr = readFileSync("settings.json", "utf-8");
    try {
        Object.assign(settings, JSON.parse(settingsStr));
        readFileSync("settings.json", "utf-8");
    } catch (e) {
        console.error(
            `CODE00000000 Using default settings because failed to parse settings.json, see error below`,
            e,
        );
    }
} catch (e) {
    console.log(`Couldn't find settings.json file`);
}

const ui_api_meta_str = `ui_api_meta = ${jsObjectToLua(ui_api_meta)}`;

writeFileSync("update_ui_funcs.lua", generatedContent, "utf-8");
for (let copyToPath of settings.copyToPath) {
    const resolvedFolder = resolve(copyToPath);
    console.log(`Writing to ${resolvedFolder}...`);
    writeFileSync(
        resolve(resolvedFolder, "update_ui_funcs.lua"),
        generatedContent,
        "utf-8",
    );
    writeFileSync(
        resolve(resolvedFolder, "ui_api_meta.lua"),
        ui_api_meta_str,
        "utf-8",
    );
}
