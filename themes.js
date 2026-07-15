import { darkHighlightColors, lightHighlightColors } from "./colors.js";
export const SYNTAX_THEME_IDS = [
    "github",
    "catppuccin",
    "dracula",
    "tokyo-night",
    "one",
    "nord",
    "gruvbox",
    "solarized",
];
export const SYNTAX_THEME_OPTIONS = [
    { id: "github", label: "GitHub" },
    { id: "catppuccin", label: "Catppuccin" },
    { id: "dracula", label: "Dracula" },
    { id: "tokyo-night", label: "Tokyo Night" },
    { id: "one", label: "One" },
    { id: "nord", label: "Nord" },
    { id: "gruvbox", label: "Gruvbox" },
    { id: "solarized", label: "Solarized" },
];
function expandRolePalette(r) {
    return {
        keyword: r.keyword,
        comment: r.comment,
        string: r.string,
        number: r.number,
        literal: r.number,
        function: r.function,
        definition: r.function,
        class: r.type,
        type: r.type,
        tag: r.tag,
        attribute: r.attribute,
        property: r.attribute,
        variable: r.base,
        operator: r.operator,
        punctuation: r.base,
        regexp: r.string,
        escape: r.number,
        meta: r.comment,
        heading: r.function,
        link: r.string,
    };
}
// --- Catppuccin (Latte light / Mocha dark) -------------------------------
const catppuccinLatte = {
    base: "#4c4f69",
    keyword: "#8839ef",
    comment: "#8c8fa1",
    string: "#40a02b",
    number: "#fe640b",
    function: "#1e66f5",
    type: "#df8e1d",
    tag: "#8839ef",
    attribute: "#df8e1d",
    operator: "#04a5e5",
};
const catppuccinMocha = {
    base: "#cdd6f4",
    keyword: "#cba6f7",
    comment: "#9399b2",
    string: "#a6e3a1",
    number: "#fab387",
    function: "#89b4fa",
    type: "#f9e2af",
    tag: "#cba6f7",
    attribute: "#f9e2af",
    operator: "#89dceb",
};
// --- Dracula (dark only) -------------------------------------------------
const dracula = {
    base: "#f8f8f2",
    keyword: "#ff79c6",
    comment: "#6272a4",
    string: "#f1fa8c",
    number: "#bd93f9",
    function: "#50fa7b",
    type: "#8be9fd",
    tag: "#ff79c6",
    attribute: "#50fa7b",
    operator: "#ff79c6",
};
// --- Tokyo Night (Day light / Night dark) --------------------------------
const tokyoDay = {
    base: "#3760bf",
    keyword: "#9854f1",
    comment: "#848cb5",
    string: "#587539",
    number: "#b15c00",
    function: "#2e7de9",
    type: "#007197",
    tag: "#f52a65",
    attribute: "#8c6c3e",
    operator: "#006a83",
};
const tokyoNight = {
    base: "#c0caf5",
    keyword: "#bb9af7",
    comment: "#565f89",
    string: "#9ece6a",
    number: "#ff9e64",
    function: "#7aa2f7",
    type: "#2ac3de",
    tag: "#f7768e",
    attribute: "#e0af68",
    operator: "#89ddff",
};
// --- One (One Light / One Dark) ------------------------------------------
const oneLight = {
    base: "#383a42",
    keyword: "#a626a4",
    comment: "#a0a1a7",
    string: "#50a14f",
    number: "#986801",
    function: "#4078f2",
    type: "#c18401",
    tag: "#e45649",
    attribute: "#986801",
    operator: "#0184bc",
};
const oneDark = {
    base: "#abb2bf",
    keyword: "#c678dd",
    comment: "#5c6370",
    string: "#98c379",
    number: "#d19a66",
    function: "#61afef",
    type: "#e5c07b",
    tag: "#e06c75",
    attribute: "#d19a66",
    operator: "#56b6c2",
};
// --- Nord (Snow Storm light / Polar Night dark) ---------------------------
const nordLight = {
    base: "#2e3440",
    keyword: "#5e81ac",
    comment: "#6b7280",
    string: "#4f6f3a",
    number: "#8f5e91",
    function: "#2e6f8e",
    type: "#3b7f87",
    tag: "#5e81ac",
    attribute: "#8f5e91",
    operator: "#5e81ac",
};
const nordDark = {
    base: "#d8dee9",
    keyword: "#81a1c1",
    comment: "#616e88",
    string: "#a3be8c",
    number: "#b48ead",
    function: "#88c0d0",
    type: "#8fbcbb",
    tag: "#81a1c1",
    attribute: "#8fbcbb",
    operator: "#81a1c1",
};
// --- Gruvbox (Light / Dark) ----------------------------------------------
const gruvboxLight = {
    base: "#3c3836",
    keyword: "#9d0006",
    comment: "#928374",
    string: "#79740e",
    number: "#8f3f71",
    function: "#427b58",
    type: "#b57614",
    tag: "#076678",
    attribute: "#b57614",
    operator: "#af3a03",
};
const gruvboxDark = {
    base: "#ebdbb2",
    keyword: "#fb4934",
    comment: "#928374",
    string: "#b8bb26",
    number: "#d3869b",
    function: "#8ec07c",
    type: "#fabd2f",
    tag: "#83a598",
    attribute: "#fabd2f",
    operator: "#fe8019",
};
// --- Solarized (Light / Dark — shared accents, different base/comment) ----
const solarizedLight = {
    base: "#657b83",
    keyword: "#859900",
    comment: "#93a1a1",
    string: "#2aa198",
    number: "#d33682",
    function: "#268bd2",
    type: "#b58900",
    tag: "#268bd2",
    attribute: "#b58900",
    operator: "#859900",
};
const solarizedDark = {
    base: "#839496",
    keyword: "#859900",
    comment: "#586e75",
    string: "#2aa198",
    number: "#d33682",
    function: "#268bd2",
    type: "#b58900",
    tag: "#268bd2",
    attribute: "#b58900",
    operator: "#859900",
};
export function isSyntaxThemeId(value) {
    return SYNTAX_THEME_IDS.includes(value);
}
// Resolve a theme id + the app's color scheme to a full token palette. Only the
// light/dark axis is coupled to the app; the theme brand is the user's choice.
export function resolveSyntaxColors(id, colorScheme) {
    const dark = colorScheme === "dark";
    switch (id) {
        case "github":
            return dark ? darkHighlightColors : lightHighlightColors;
        case "catppuccin":
            return expandRolePalette(dark ? catppuccinMocha : catppuccinLatte);
        case "dracula":
            return expandRolePalette(dracula);
        case "tokyo-night":
            return expandRolePalette(dark ? tokyoNight : tokyoDay);
        case "one":
            return expandRolePalette(dark ? oneDark : oneLight);
        case "nord":
            return expandRolePalette(dark ? nordDark : nordLight);
        case "gruvbox":
            return expandRolePalette(dark ? gruvboxDark : gruvboxLight);
        case "solarized":
            return expandRolePalette(dark ? solarizedDark : solarizedLight);
    }
}
//# sourceMappingURL=themes.js.map