# Iguana Game Engine
A game engine written in zig that will be as portable as I can handle.

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

## Navmesh
This is where ZigVGCore might shine compared to some mainstream engines. The navmesh will optionally be generatable on walls and ceilings, and the built-in pathfinding system will have crowd management that handles thousands of pathfinders.

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
  <li>...</li>
</ul>
