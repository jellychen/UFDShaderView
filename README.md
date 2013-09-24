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

Fragment Shader Uniforms
========================

```glsl
uniform float time; // time in seconds
uniform vec2 touch; // location of current touch
uniform vec2 resolution; // resolution of the view
```

License
=======

Credits would be nice I guess.
