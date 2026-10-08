// Welcome to Greenpad.
// A small, native Mac editor for your everyday text and code.

const editor = {
    name: "Greenpad",
    platform: "macOS",
    builtWith: ["Swift", "AppKit"],
    philosophy: "Open a file. Make a change. Get on with your day."
};

function sayHello(name) {
    return `Hello, ${name}. Make yourself at home.`;
}

console.log(sayHello(editor.name));

// A few familiar shortcuts:
//   ⌘N   New tab             ⌘O   Open files
//   ⌘S   Save                ⌘W   Close tab
//   ⌘F   Find & replace      ⌘G   Find next
//   ⌘L   Go to line          ⌥⌘W  Word wrap
//
// Try searching for "editor", or choose a language in the status bar.
// Greenpad is independent software, inspired by Notepad++.
