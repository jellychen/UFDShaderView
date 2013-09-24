UFDShaderView
=============

A UIView subclass for rendering an OpenGL ES 2.0 fragment shader

Usage
=====

This example creates a shader view, loads the example shader source, and animates it at 30 frames per second.

```objective-c
UFDShaderView *shaderView = [[UFDShaderView alloc] initWithFrame:self.view.bounds];
[shaderView loadFragmentShader:kUFDShaderViewExampleFragmentShaderSource error:nil];
shaderView.animating = YES;
[self.view addSubview:shaderView];
```

This will make this awesome thingy appear:

![alt tag](http://f.cl.ly/items/3T202d022n2C0G3K1P1d/Screen%20Shot%202013-09-24%20at%2012.25.06%20.png)

Fragment Shader Uniforms
========================

```glsl
uniform float time; // time in seconds
uniform vec2 touch; // location of current touch
uniform vec2 resolution; // resolution of the view
```

TODO
====

* Retina support
* OpenGL ES 3.0
* CocoaPod

License
=======

Credits would be nice I guess.
