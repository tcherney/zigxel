# Zigxel
A "pixel" based game engine in the terminal
Using my image library [zig-image](https://github.com/tcherney/zig-image) and [terminal](https://github.com/tcherney/terminal) library
- [wasm build of falling sand game](https://tcherney.github.io)
#### TODO
-  tui more element types
-  isometric camera, 3D
-  more biome generation, more pixel types
-  create an actual game within in the falling sand world, flesh out player add enemies, etc
-  refactor pass, cleanup names and stray commented code
-  improve debug view to have a better idea of whats happening in real time
-  improve effciency of game objects, large game objects slow down sim a lot
-  improve font rendering
-  handle more events
-  multithread renedering pipeline, most time spent in io so wont do much
-  audio handling, openal?
-  Auto scaling rendering
