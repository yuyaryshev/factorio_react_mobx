const cheerio = require("cheerio");

const trimmedChar = (c)=>(
        c === " "
    ||  c === "\t"
    ||  c === "\r"
    ||  c === "\n"
    ||  c === ":"
    ||  c === "-"
    ||  c === "."
        ||  c === ";"
        ||  c === "="
        ||  c === "+"
        ||  c === "*"
        ||  c === "/"
        ||  c === "\\"
);

const superTrim = (s) => {
    if(typeof s === "string"){
        let st=0;
        while(st<s.length && trimmedChar(s[st]))
            st++;

        let e = s.length;
        while(st<=e-1 && trimmedChar(s[e-1]))
            e--;
        return s.substring(st,e);
        }
    return s;
};

cheerio.prototype.this_text = function this_text() {
    // superTrim(
    return  typeof this === "string" ? this :this
        .first()
        .contents()
        .filter(function() {
            return this.type === "text";
        })
        .text()
         .split(/[\:]/g)
         .map(s => superTrim(s))
         .join("");
};

cheerio.prototype.full_text = function full_text() {
    return  superTrim(this
        .text()
        .split(/[\:]/g)
        .map(s =>  superTrim(s))
        .join("")
        .trim());
};

module.exports = cheerio;