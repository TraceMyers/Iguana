# Kochi Engine
A game engine written in zig that will be as portable as I can handle.

Current zig version is an old dev version (0.11.0-dev.3105+e46d7a369). I'll be more responsible with versioning as the engine really starts to take shape.

## Getting Started
TBD

## Level Editor
A graphical interface for making levels. At this point, the details are uncertain, but it will be much lighter than mainstream editors.

## Renderer
A highly parameterizable Vulkan-based renderer with systems for handling static meshes, skeletal meshes, instancing, particles, and many other common features.

There are currently no plans to use any APIs other than Vulkan.

## Physics
...

## Allocator
Every game engine needs a smart strategy for making allocation syscalls. Having a fast, low-fragmentation, debuggable allocator on your side can lighten the load.

## Sound
...

## Math
A custom vector math library, because I enjoy writing vector math.

## Misc
<ul>
  <li>Entity Component System</li>
  <li>Benchmarking suite</li>
  <li>Convenient stack and heap array implementations</li>
  <li>Graphical debug utilities</li>
  <li>Extensible SIMD</li>
  <li>...</li>
</ul>
