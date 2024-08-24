# Zigxel
A "pixel" based game engine in the terminal
Using my image library [zig-image](https://github.com/tcherney/zig-image) and [terminal](https://github.com/tcherney/terminal) library

## TODO
- [x]  Split texture out with sprite struct
- [x]  split out image and term structs into seperate libraries that are depended on
- [x]  move image processing functions to image struct and refactor image struct with an interface for common functions used across all image types
- [ ]  event handling on linux tested and fixed
- [x]  key event callbacks refactored to work with self pointers like window callback
- [ ]  poc pixel sim to use the engine